//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#include "emb_profile_store.h"

#if !TARGET_OS_WATCH

#include <errno.h>
#include <fcntl.h>
#include <mach/mach.h>     // vm_page_size
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

// Data-protection Class B == NSFileProtectionCompleteUnlessOpen. It is the only class we use: it keeps
// an already-open file writable while the device is locked, which is exactly this file's lifetime (we
// hold it open for the whole session). The protection-class enum constants (PROTECTION_CLASS_*) are NOT
// exported by the public SDK headers — only F_SETPROTECTIONCLASS is — so we use the documented integer
// value directly. No other class is defined here because none is needed.
#define EMB_PROTECTION_CLASS_B 2

struct emb_profile_store {
    int fd;
    void *base;               // base of the address-space reservation
    size_t reserve_size;      // total reserved bytes (for munmap)
    size_t data_capacity;     // page-aligned data region size
    size_t footer_bytes;      // page-aligned footer size
    size_t page;              // vm page size used at creation
    void *footer;             // start of the mapped footer ([control page][metadata page]); for flush
    void *meta_page;          // the write-once metadata page (mprotect-toggled for version writes)
    emb_profile_ident_t *ident; // frozen identity within the metadata page
    emb_ring_buffer_t *ring;  // attached ring buffer (owns_resources == false)
};

/// Write `version` into the frozen identity, briefly toggling the write-once metadata
/// page to RW. The version field is the file's transactional validity/tombstone marker
/// (PROFILING-DISK-FORMAT.md §5): 0 = "disregard"; a real version = recoverable.
static void store_set_version(emb_profile_store_t *store, uint64_t version)
{
    // Toggle the write-once metadata page to RW just for this write. mprotect on our own mapped page is
    // not expected to fail in practice — this is purely defensive. If the unprotect does fail the page
    // is still read-only — writing would SIGBUS and crash the host app — so bail and leave the current
    // version intact. Worst case the file keeps version 1 and is re-reported as a crash next launch (a
    // harmless false positive: recovery finds a valid file with no torn tail), never a fault.
    if (mprotect(store->meta_page, store->page, PROT_READ | PROT_WRITE) != 0) { return; }
    store->ident->format_version = version;
    (void)mprotect(store->meta_page, store->page, PROT_READ);  // best-effort re-protect
}

static size_t round_up_to_page(size_t n, size_t page)
{
    return (n + page - 1) & ~(page - 1);
}

emb_profile_store_t *emb_profile_store_create(const char *path,
                                              size_t capacity_bytes,
                                              const uint8_t session_id[16],
                                              int *errno_out)
{
    int dummy_errno = 0;
    if (errno_out == NULL) { errno_out = &dummy_errno; }
    *errno_out = 0;

    if (path == NULL || capacity_bytes == 0) {
        *errno_out = EINVAL;
        return NULL;
    }

    const size_t page = (size_t)vm_page_size;
    const size_t data_capacity = round_up_to_page(capacity_bytes, page);
    // Footer = one RW control-block page + one write-once metadata page.
    const size_t footer_bytes = 2 * page;
    const size_t guard_bytes = page;
    const off_t  file_size = (off_t)(data_capacity + footer_bytes);
    const size_t reserve_size = 2 * data_capacity + guard_bytes + footer_bytes;

    // --- open + size the file ---
    // O_NOFOLLOW: the directory is caller-provided, so refuse to follow a symlink at the final
    // path component and truncate an unexpected file (matches the symlink hardening in recovery).
    int fd = open(path, O_RDWR | O_CREAT | O_TRUNC | O_NOFOLLOW, 0600);
    if (fd < 0) { *errno_out = errno; return NULL; }

#if !TARGET_OS_OSX
    // Class B = NSFileProtectionCompleteUnlessOpen: an open file keeps accepting writes while the
    // device is locked (we hold it open for the whole session). Best-effort, non-fatal. Applied on
    // every data-protection platform (iOS/iPadOS/tvOS/visionOS); excluded only on macOS, where
    // F_SETPROTECTIONCLASS is meaningless and the host C-layer tests run.
    (void)fcntl(fd, F_SETPROTECTIONCLASS, EMB_PROTECTION_CLASS_B);
#endif

    if (ftruncate(fd, file_size) != 0) { *errno_out = errno; close(fd); return NULL; }

    // --- reserve address space, then place the double-mapped data + guard + footer ---
    void *base = mmap(NULL, reserve_size, PROT_NONE, MAP_ANON | MAP_PRIVATE, -1, 0);
    if (base == MAP_FAILED) { *errno_out = errno; close(fd); return NULL; }

    uint8_t *b = (uint8_t *)base;
    // Lower half + aliased upper half: both MAP_SHARED over file offset 0, so a record that
    // wraps past the end is written through the alias into the single file region.
    if (mmap(b, data_capacity, PROT_READ | PROT_WRITE,
             MAP_SHARED | MAP_FIXED, fd, 0) == MAP_FAILED) { goto fail; }
    if (mmap(b + data_capacity, data_capacity, PROT_READ | PROT_WRITE,
             MAP_SHARED | MAP_FIXED, fd, 0) == MAP_FAILED) { goto fail; }
    // Guard page at b + 2*data_capacity stays PROT_NONE (never mapped over) — §7 (guard page).
    uint8_t *footer = b + 2 * data_capacity + guard_bytes;
    if (mmap(footer, footer_bytes, PROT_READ | PROT_WRITE,
             MAP_SHARED | MAP_FIXED, fd, (off_t)data_capacity) == MAP_FAILED) { goto fail; }

    // --- footer layout: [control page][write-once metadata page] ---
    // Control block at the start of the footer (its own RW page); zero from ftruncate, so the
    // fresh session's write_pos/oldest_pos/next_seq are all 0.
    emb_ring_control_t *control = (emb_ring_control_t *)footer;

    // Descriptor at the start of the metadata page; identity at the very end of the file;
    // trailer immediately before identity.
    uint8_t *meta = footer + page;
    emb_profile_descriptor_t *desc = (emb_profile_descriptor_t *)meta;
    emb_profile_ident_t *ident =
        (emb_profile_ident_t *)(footer + footer_bytes - sizeof(emb_profile_ident_t));
    emb_profile_trailer_v1_t *trailer =
        (emb_profile_trailer_v1_t *)((uint8_t *)ident - sizeof(emb_profile_trailer_v1_t));

    // --- write the write-once metadata ---
    desc->created_uptime_ns = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);
    desc->created_wall_ns   = clock_gettime_nsec_np(CLOCK_REALTIME);
    if (session_id != NULL) { memcpy(desc->session_id, session_id, 16); }
    else                    { memset(desc->session_id, 0, 16); }
    desc->image_table_offset = 0;  // absent in v1
    desc->image_table_bytes  = 0;

    trailer->footer_offset       = data_capacity;
    trailer->data_capacity       = data_capacity;
    trailer->page_size           = (uint32_t)page;
    trailer->record_header_bytes = (uint16_t)sizeof(emb_ring_record_header_t);
    trailer->pointer_bytes       = (uint16_t)sizeof(uintptr_t);
    trailer->footer_bytes        = (uint32_t)footer_bytes;
    trailer->trailer_bytes       = (uint32_t)sizeof(emb_profile_trailer_v1_t);

    ident->magic = EMB_PROFILE_FILE_MAGIC;
    // Commit LAST: a crash before this leaves format_version == 0 → recovery disregards the file (§5).
    ident->format_version = EMB_PROFILE_FORMAT_VER;

    // --- harden: drop the write-once metadata page to read-only (control page stays RW) ---
    // Best-effort: the store is fully functional whether or not this succeeds (write-once protection is
    // defense-in-depth). Failing it here would discard a working store AND leave an already-committed
    // file on disk, so we don't treat it as fatal.
    (void)mprotect(meta, page, PROT_READ);

    // --- attach a ring buffer over the data region + mapped control block ---
    emb_ring_buffer_t *ring = emb_ring_buffer_attach(b, data_capacity, control);
    if (ring == NULL) { *errno_out = ENOMEM; goto fail; }

    emb_profile_store_t *store = calloc(1, sizeof(*store));
    if (store == NULL) { *errno_out = ENOMEM; emb_ring_buffer_destroy(ring); goto fail; }
    store->fd            = fd;
    store->base          = base;
    store->reserve_size  = reserve_size;
    store->data_capacity = data_capacity;
    store->footer_bytes  = footer_bytes;
    store->page          = page;
    store->footer        = footer;
    store->meta_page     = meta;
    store->ident         = ident;
    store->ring          = ring;
    return store;

fail:
    if (*errno_out == 0) { *errno_out = errno; }
    munmap(base, reserve_size);
    close(fd);
    return NULL;
}

emb_ring_buffer_t *emb_profile_store_buffer(emb_profile_store_t *store)
{
    return store ? store->ring : NULL;
}

bool emb_profile_store_reset(emb_profile_store_t *store)
{
    if (store == NULL) { return false; }
    // Transactional reset (PROFILING-DISK-FORMAT.md §5): bracket the mutation with the
    // version marker so a crash mid-reset leaves format_version == 0 → recovery disregards a half-cleared
    // file. The file length never changes within a process run, so we reuse the same mapping/file.
    store_set_version(store, EMB_PROFILE_FORMAT_INVALID);
    bool ok = emb_ring_buffer_reset(store->ring);  // memset data + reset positions (reader-safe)
    store_set_version(store, EMB_PROFILE_FORMAT_VER);  // consistent again (also restores on reader-blocked reset)
    return ok;
}

void emb_profile_store_finalize(emb_profile_store_t *store)
{
    if (store == NULL) { return; }
    // Clean-stop tombstone (PROFILING-DISK-FORMAT.md §5): version → 0 marks the file "finalized" so
    // recovery reports nothing for it (its samples were already retrieved via the live
    // retrieveSamples path before the clean stop). We never delete — Embrace owns deletion.
    store_set_version(store, EMB_PROFILE_FORMAT_INVALID);
}

void emb_profile_store_flush(emb_profile_store_t *store)
{
    if (store == NULL) { return; }
    // Async flush of dirty pages to the file ahead of a possible background Jetsam kill. The lower data
    // half covers the file data region (the upper half aliases the same file pages); the footer holds the
    // control block + metadata. MS_ASYNC: schedule writeback, don't block.
    msync(store->base, store->data_capacity, MS_ASYNC);
    msync(store->footer, store->footer_bytes, MS_ASYNC);  // exact mapped footer base (no guard-size coupling)
}

void emb_profile_store_destroy(emb_profile_store_t *store)
{
    if (store == NULL) { return; }
    // The ring buffer was attached (owns_resources == false), so this frees only the wrapper —
    // never the mapping or the control block, which the store owns and unmaps below.
    if (store->ring != NULL) { emb_ring_buffer_destroy(store->ring); }
    if (store->base != NULL) { munmap(store->base, store->reserve_size); }
    if (store->fd >= 0)      { close(store->fd); }
    free(store);
}

// MARK: - Recovery (read-only)

// Open a candidate file read-only without following symlinks, retrying on EINTR so a signal landing
// during launch-time recovery doesn't spuriously fail the open.
static int recover_open(const char *path)
{
    int fd;
    do { fd = open(path, O_RDONLY | O_NOFOLLOW); } while (fd < 0 && errno == EINTR);
    return fd;
}

// Read exactly `n` bytes at `off`. Loops over partial reads and retries EINTR — a signal during the
// launch-time recovery read must not fail an otherwise-valid file. Returns false on a short read
// (EOF before `n`) or a real I/O error.
static bool pread_exact(int fd, void *buf, size_t n, off_t off)
{
    uint8_t *p = (uint8_t *)buf;
    size_t got = 0;
    while (got < n) {
        ssize_t r = pread(fd, p + got, n - got, off + (off_t)got);
        if (r > 0) { got += (size_t)r; continue; }
        if (r < 0 && errno == EINTR) { continue; }
        return false;  // r == 0 (short read / EOF) or a real error
    }
    return true;
}

emb_profile_recover_status_t emb_profile_recover(const char *path,
                                                 emb_profile_record_cb emit,
                                                 void *ctx)
{
    if (path == NULL) { return EMB_PROFILE_RECOVER_IO_ERROR; }

    // O_NOFOLLOW: don't traverse a symlink left in the recovery directory (hardening for untrusted
    // input). recover_open retries EINTR so a signal during the read doesn't spuriously fail.
    int fd = recover_open(path);
    if (fd < 0) { return EMB_PROFILE_RECOVER_IO_ERROR; }

    emb_profile_recover_status_t status = EMB_PROFILE_RECOVER_CORRUPT;

    struct stat st;
    if (fstat(fd, &st) != 0) { status = EMB_PROFILE_RECOVER_IO_ERROR; goto done; }
    if (!S_ISREG(st.st_mode)) { status = EMB_PROFILE_RECOVER_NOT_OURS; goto done; }  // dirs/devices/etc.
    const off_t file_size = st.st_size;
    if (file_size < (off_t)(sizeof(emb_profile_ident_t) + sizeof(emb_profile_trailer_v1_t))) {
        goto done;  // too small to be valid → CORRUPT
    }

    // --- frozen identity at EOF − 16: magic + version gate ---
    emb_profile_ident_t ident;
    if (!pread_exact(fd, &ident, sizeof(ident), file_size - (off_t)sizeof(ident))) {
        status = EMB_PROFILE_RECOVER_IO_ERROR; goto done;
    }
    if (ident.magic != EMB_PROFILE_FILE_MAGIC) { status = EMB_PROFILE_RECOVER_NOT_OURS; goto done; }
    if (ident.format_version == EMB_PROFILE_FORMAT_INVALID) { status = EMB_PROFILE_RECOVER_FINALIZED; goto done; }
    if (ident.format_version != EMB_PROFILE_FORMAT_VER) { status = EMB_PROFILE_RECOVER_UNSUPPORTED; goto done; }

    // --- v1 trailer (immediately before the identity), validated ---
    emb_profile_trailer_v1_t tr;
    const off_t trailer_off = file_size - (off_t)sizeof(ident) - (off_t)sizeof(tr);
    if (!pread_exact(fd, &tr, sizeof(tr), trailer_off)) { status = EMB_PROFILE_RECOVER_IO_ERROR; goto done; }
    if (tr.page_size != (uint32_t)vm_page_size ||
        tr.record_header_bytes != (uint16_t)sizeof(emb_ring_record_header_t) ||
        tr.pointer_bytes != (uint16_t)sizeof(uintptr_t) ||
        tr.data_capacity == 0 ||
        (tr.data_capacity % (uint64_t)vm_page_size) != 0 ||        // must be page-aligned
        tr.data_capacity > (uint64_t)file_size ||                  // can't exceed the real file (anti-overflow)
        tr.footer_bytes < 2 * (uint64_t)vm_page_size ||            // at least control + metadata page
        tr.footer_offset != tr.data_capacity ||
        (off_t)(tr.data_capacity + tr.footer_bytes) != file_size) {
        goto done;  // mismatch → CORRUPT (page-size / record-size / endian / out-of-range rejected here)
    }
    const size_t data_capacity = (size_t)tr.data_capacity;

    // --- control block (trusted but validated; option B): write_pos@0, oldest_pos@8 ---
    uint64_t write_pos = 0, oldest_pos = 0;
    if (!pread_exact(fd, &write_pos, sizeof(write_pos), (off_t)data_capacity) ||
        !pread_exact(fd, &oldest_pos, sizeof(oldest_pos), (off_t)data_capacity + (off_t)sizeof(uint64_t))) {
        status = EMB_PROFILE_RECOVER_IO_ERROR; goto done;
    }
    if (oldest_pos > write_pos || (write_pos - oldest_pos) > data_capacity) {
        goto done;  // inconsistent positions → discard (CORRUPT)
    }
    if (write_pos == oldest_pos) { status = EMB_PROFILE_RECOVER_OK; goto done; }  // empty — nothing to emit

    // --- double-map the data region (read-only) so wrapped records are contiguous ---
    const size_t map_reserve = 2 * data_capacity;
    void *base = mmap(NULL, map_reserve, PROT_NONE, MAP_ANON | MAP_PRIVATE, -1, 0);
    if (base == MAP_FAILED) { status = EMB_PROFILE_RECOVER_IO_ERROR; goto done; }
    uint8_t *b = (uint8_t *)base;
    if (mmap(b, data_capacity, PROT_READ, MAP_SHARED | MAP_FIXED, fd, 0) == MAP_FAILED ||
        mmap(b + data_capacity, data_capacity, PROT_READ, MAP_SHARED | MAP_FIXED, fd, 0) == MAP_FAILED) {
        munmap(base, map_reserve);
        status = EMB_PROFILE_RECOVER_IO_ERROR; goto done;
    }

    // --- walk records oldest_pos → write_pos, torn-tail tolerant ---
    // write_pos/oldest_pos are absolute monotonic byte counters (indexed via % data_capacity), so over
    // a long session write_pos grows large — we must NOT cap it. Loop invariant: oldest_pos <= pos <=
    // write_pos and (write_pos - oldest_pos) <= data_capacity. We therefore compare on the remaining
    // span `write_pos - pos` (subtraction, never underflows) instead of `pos + size` — the latter can
    // overflow uint64 on a crafted file whose write_pos sits within one record of UINT64_MAX, which
    // would defeat the overrun guard and read past the 2*data_capacity mapping. With the subtraction
    // form, rsize <= write_pos - pos <= data_capacity, so (pos % data_capacity) + rsize <= 2*cap-1,
    // always inside the double map.
    const size_t hdr_size = sizeof(emb_ring_record_header_t);
    uint64_t pos = oldest_pos;
    while (write_pos - pos >= hdr_size) {
        const emb_ring_record_header_t *h =
            (const emb_ring_record_header_t *)(b + (pos % data_capacity));
        if (h->seq & 1u) { break; }                            // odd seq = writer died mid-record (torn)
        if (h->frame_count == 0) { break; }                    // zeroed/unflushed page — not a real record (B1)
        if (h->frame_count > EMB_MAX_STACK_FRAMES) { break; }  // garbage
        const size_t rsize = hdr_size + (size_t)h->frame_count * sizeof(uintptr_t);
        if (rsize > write_pos - pos) { break; }                // record overruns committed data
        if (emit != NULL) {
            const uintptr_t *frames = (const uintptr_t *)((const uint8_t *)h + hdr_size);
            emit(ctx, h->timestamp_ns, h->thread_state, h->flags, frames, h->frame_count);
        }
        pos += rsize;
    }

    munmap(base, map_reserve);
    status = EMB_PROFILE_RECOVER_OK;

done:
    close(fd);
    return status;
}

emb_profile_peek_status_t emb_profile_peek(const char *path)
{
    if (path == NULL) { return EMB_PROFILE_PEEK_NOT_OURS; }

    // A file we can't open/stat/read may still be one of ours — it could be locked under data
    // protection (Class B) at launch, or hit a transient EINTR/EIO — so those map to INDETERMINATE,
    // NOT to NOT_OURS, so the caller doesn't permanently write it off. Only a readable regular file
    // whose magic doesn't match is definitively NOT_OURS.
    int fd = recover_open(path);
    if (fd < 0) { return EMB_PROFILE_PEEK_INDETERMINATE; }

    emb_profile_peek_status_t result;
    struct stat st;
    emb_profile_ident_t ident;
    if (fstat(fd, &st) != 0) {
        result = EMB_PROFILE_PEEK_INDETERMINATE;                       // couldn't stat
    } else if (!S_ISREG(st.st_mode) || st.st_size < (off_t)sizeof(ident)) {
        result = EMB_PROFILE_PEEK_NOT_OURS;                           // not a regular file / too small
    } else if (!pread_exact(fd, &ident, sizeof(ident), st.st_size - (off_t)sizeof(ident))) {
        result = EMB_PROFILE_PEEK_INDETERMINATE;                       // couldn't read the identity
    } else if (ident.magic != EMB_PROFILE_FILE_MAGIC) {
        result = EMB_PROFILE_PEEK_NOT_OURS;                           // read it — magic mismatch
    } else {
        result = (ident.format_version == EMB_PROFILE_FORMAT_INVALID)
            ? EMB_PROFILE_PEEK_FINALIZED
            : EMB_PROFILE_PEEK_RECOVERABLE;
    }
    close(fd);
    return result;
}

#endif /* !TARGET_OS_WATCH */
