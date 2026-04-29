//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#include "emb_ring_buffer.h"

#if !TARGET_OS_WATCH

#include <mach/mach.h>
#include <mach/vm_map.h>
#include <os/log.h>
#include <stdlib.h>
#include <string.h>

// mach_vm_* functions are macOS-only; on iOS/tvOS we use vm_* equivalents
#if TARGET_OS_OSX
#include <mach/mach_vm.h>
typedef mach_vm_address_t emb_vm_address_t;
typedef mach_vm_size_t emb_vm_size_t;
#define emb_vm_allocate mach_vm_allocate
#define emb_vm_remap mach_vm_remap
#define emb_vm_deallocate mach_vm_deallocate
#else
typedef vm_address_t emb_vm_address_t;
typedef vm_size_t emb_vm_size_t;
#define emb_vm_allocate vm_allocate
#define emb_vm_remap vm_remap
#define emb_vm_deallocate vm_deallocate
#endif

// Internal write header with atomic seq for the seqlock protocol.
// Layout-compatible with the public emb_ring_record_header_t.
typedef struct {
    _Atomic uint32_t seq;
    uint32_t frame_count;
    uint64_t timestamp_ns;
} emb_ring_write_header_t;

_Static_assert(sizeof(emb_ring_write_header_t) == sizeof(emb_ring_record_header_t),
               "write header must match public header layout");
_Static_assert(_Alignof(emb_ring_write_header_t) == _Alignof(emb_ring_record_header_t),
               "write header alignment must match public header");
_Static_assert(offsetof(emb_ring_write_header_t, seq) == offsetof(emb_ring_record_header_t, seq),
               "seq offset mismatch");
_Static_assert(offsetof(emb_ring_write_header_t, frame_count) == offsetof(emb_ring_record_header_t, frame_count),
               "frame_count offset mismatch");
_Static_assert(offsetof(emb_ring_write_header_t, timestamp_ns) == offsetof(emb_ring_record_header_t, timestamp_ns),
               "timestamp_ns offset mismatch");

static const size_t header_size = sizeof(emb_ring_record_header_t);
static const size_t frame_size = sizeof(uintptr_t);

/// Calculate the size of a record with the given number of frames.
/// This will work out to the header size + 8 bytes per frame.
static inline size_t record_size(size_t frame_count)
{
    return header_size + frame_size * frame_count;
}

static size_t round_size_up_to_page_boundary(size_t size)
{
    size_t page = vm_page_size;
    return (size + page - 1) & ~(page - 1);
}

emb_ring_buffer_t *emb_ring_buffer_create(size_t capacity_bytes)
{
    const size_t capacity = round_size_up_to_page_boundary(capacity_bytes);
    if (capacity == 0) {
        return NULL;
    }

    // Allocate a contiguous virtual region of 2 * capacity.
    // The second half will be remapped to alias the first half's physical pages,
    // so writes past the end of the first half seamlessly wrap around.
    const emb_vm_size_t half = (emb_vm_size_t)capacity;
    const emb_vm_size_t region_size = half * 2;

    bool remap_succeeded = false;

    emb_vm_address_t region = 0;
    kern_return_t kr = emb_vm_allocate(mach_task_self(),
                                       &region,
                                       region_size,
                                       VM_FLAGS_ANYWHERE);
    if (kr != KERN_SUCCESS) {
        return NULL;
    }

    // Remap the first half's physical pages over the second half.
    // copy = false so both halves share the same physical pages rather than
    // getting an independent copy.
    emb_vm_address_t second_half = region + half;
    vm_prot_t cur_prot = VM_PROT_NONE;
    vm_prot_t max_prot = VM_PROT_NONE;

    kr = emb_vm_remap(mach_task_self(),
                      &second_half,
                      half,
                      0,                                   // alignment mask
                      VM_FLAGS_FIXED | VM_FLAGS_OVERWRITE,
                      mach_task_self(),
                      region,                              // source = first half
                      false,                               // copy
                      &cur_prot,
                      &max_prot,
                      VM_INHERIT_NONE);
    if (kr != KERN_SUCCESS) {
        goto fail;
    }

    remap_succeeded = true;

    // Sanity-check: with VM_FLAGS_FIXED | VM_FLAGS_OVERWRITE this branch is
    // unreachable — the kernel must place the mapping at the requested address.
    if (second_half != region + half) {
        goto fail;
    }

    emb_ring_buffer_t *buf = calloc(1, sizeof(*buf));
    if (buf == NULL) {
        goto fail;
    }

    buf->data       = (uint8_t *)region;
    buf->capacity   = capacity;
    buf->next_seq   = 0;
    atomic_store_explicit(&buf->write_pos,  0, memory_order_relaxed);
    atomic_store_explicit(&buf->oldest_pos, 0, memory_order_relaxed);
    atomic_store_explicit(&buf->active_readers, 0, memory_order_relaxed);
    atomic_store_explicit(&buf->resetting, false, memory_order_relaxed);

    return buf;

fail:
    if (remap_succeeded) {
        // After vm_remap with VM_FLAGS_OVERWRITE the region may have been split
        // into two VM map entries. Deallocate each half independently.
        emb_vm_deallocate(mach_task_self(), region,        half);
        emb_vm_deallocate(mach_task_self(), region + half, half);
    } else {
        // vm_remap failed. VM_FLAGS_OVERWRITE may have already torn out the
        // second half before failing, so we can only safely free the first half.
        // The second half is either still part of the original allocation (and
        // this covers it) or already gone.
        // Note: vm_deallocate on XNU handles partially-mapped ranges gracefully,
        // so passing the full region_size is safe even if parts are already gone.
        emb_vm_deallocate(mach_task_self(), region, region_size);
    }
    return NULL;
}

void emb_ring_buffer_destroy(emb_ring_buffer_t *buf)
{
    if (buf == NULL) {
        return;
    }
    // Deallocate the full 2 × capacity virtual region (both the original
    // allocation and the remap share the same address range).
    emb_vm_deallocate(mach_task_self(),
                      (emb_vm_address_t)buf->data,
                      (emb_vm_size_t)buf->capacity * 2);
    free(buf);
}

bool emb_ring_buffer_reset(emb_ring_buffer_t *buf)
{
    if (buf == NULL) {
        return false;
    }

    // Dekker-style mutual exclusion with read_range:
    // Both sides use seq_cst on their respective flag/counter to prevent
    // ARM64 store-buffer reordering (the classic two-flag pattern).
    atomic_store_explicit(&buf->resetting, true, memory_order_seq_cst);

    if (atomic_load_explicit(&buf->active_readers, memory_order_seq_cst) > 0) {
        atomic_store_explicit(&buf->resetting, false, memory_order_seq_cst);
        return false;
    }

    memset(buf->data, 0, buf->capacity);
    buf->next_seq = 0;
    atomic_store_explicit(&buf->write_pos, 0, memory_order_release);
    atomic_store_explicit(&buf->oldest_pos, 0, memory_order_release);

    atomic_store_explicit(&buf->resetting, false, memory_order_seq_cst);
    return true;
}

size_t emb_ring_buffer_capacity(const emb_ring_buffer_t *buf)
{
    if (buf == NULL) {
        return 0;
    }
    return buf->capacity;
}

bool emb_ring_buffer_write(emb_ring_buffer_t *buf,
                           uint64_t timestamp_ns,
                           const uintptr_t *frames,
                           size_t frame_count)
{
    if (buf == NULL || (frames == NULL && frame_count > 0)) {
        return false;
    }

    // The header stores frame_count as uint32_t.
    if (frame_count > UINT32_MAX) {
        return false;
    }

    // Record size for the requested frame count.
    size_t record_size_needed = record_size(frame_count);

    // A single record must fit within the buffer capacity.
    if (record_size_needed > buf->capacity) {
        return false;
    }

    // Current write position (monotonically increasing byte offset).
    uint64_t write_pos = atomic_load_explicit(&buf->write_pos, memory_order_relaxed);
    // relaxed: the writer is the only thread that advances oldest_pos, so no
    // synchronisation is needed here — we only need our own prior stores.
    uint64_t oldest_pos = atomic_load_explicit(&buf->oldest_pos, memory_order_relaxed);

    // Evict old records that would be overlapped by this write.
    // The loop condition: oldest_pos + capacity < write_pos + record_size
    // This means the oldest record would be overwritten.
    while (oldest_pos + buf->capacity < write_pos + record_size_needed) {
        // Read the header of the oldest record to determine its size.
        // Safe: we're the single writer and this is our own committed record.
        size_t offset = oldest_pos % buf->capacity;
        emb_ring_write_header_t *old_header = (emb_ring_write_header_t *)(buf->data + offset);
        size_t old_frame_count = old_header->frame_count;
        size_t old_record_size = record_size(old_frame_count);

        // Guard against corrupted headers (e.g. bit flip, stale VM page).
        // A valid record is always <= capacity (enforced by the write path).
        // On corruption, evict everything to prevent cascading garbage reads.
        if (old_record_size > buf->capacity) {
            oldest_pos = write_pos;
            atomic_store_explicit(&buf->oldest_pos, oldest_pos, memory_order_release);
            break;
        }

        // Advance oldest_pos past this record.
        oldest_pos += old_record_size;

        // Publish the new oldest_pos.
        atomic_store_explicit(&buf->oldest_pos, oldest_pos, memory_order_release);
    }

    // Full barrier: ensures the oldest_pos advance(s) above are globally visible
    // before the data writes below. Without this, ARM64's weak ordering allows
    // subsequent stores (the memcpy into evicted space) to become visible to
    // readers before the oldest_pos release store, causing undetectable torn reads
    // for readers that use oldest_pos to guard against eviction.
    //
    // Concrete failure without this fence:
    //   Writer                           Reader
    //   ------                           ------
    //   memcpy(new data over old)        load oldest_pos → sees OLD value
    //   store(oldest_pos, release)       read header at old position → TORN
    //
    // ARM64 allows the memcpy stores to become globally visible before the
    // release store to oldest_pos. The reader sees oldest_pos unchanged,
    // concludes its position is safe, but the data has already been
    // overwritten. The seq_cst fence closes this window.
    atomic_thread_fence(memory_order_seq_cst);

    // Now that space is guaranteed, mark the record as "writing" via seqlock.
    //
    // NOTE: The seqlock (odd seq = writing, even seq = stable) is an advisory
    // defence-in-depth mechanism. Primary read correctness comes from the
    // oldest_pos protocol in emb_ring_buffer_read_range, which checks whether
    // the writer has evicted the reader's position. The seq field provides an
    // additional signal that readers can use to detect a mid-write record, but
    // the read path does NOT rely on a full seqlock acquire/release handshake
    // for data consistency.
    size_t offset = write_pos % buf->capacity;
    emb_ring_write_header_t *header = (emb_ring_write_header_t *)(buf->data + offset);

    // Set seq to odd (writing). Release ordering ensures this store is visible
    // to readers before any subsequent data writes, which is necessary for
    // correct seqlock protocol on weakly-ordered architectures (ARM64).
    atomic_store_explicit(&header->seq, (uint32_t)(buf->next_seq | 1), memory_order_release);

    // Copy frame data into the buffer.
    uintptr_t *dest_frames = (uintptr_t *)(header + 1);
    memcpy(dest_frames, frames, frame_count * sizeof(*dest_frames));

    // Write the header fields (frame_count and timestamp).
    header->frame_count = (uint32_t)frame_count;
    header->timestamp_ns = timestamp_ns;

    // Seal the seqlock (transition to even = stable).
    atomic_store_explicit(&header->seq, (uint32_t)buf->next_seq, memory_order_release);

    // Advance write_pos by the actual record size.
    atomic_store_explicit(&buf->write_pos, write_pos + record_size(frame_count), memory_order_release);

    // Increment the seqlock counter for the next write.
    buf->next_seq += 2;

    return true;
}

/// Read a record header directly from the live ring buffer at the given
/// absolute position. The double-mapping guarantees contiguous access.
static inline emb_ring_record_header_t read_live_header(emb_ring_buffer_t *buf,
                                                         uint64_t absolute_pos) {
    size_t offset = (size_t)(absolute_pos % buf->capacity);
    const emb_ring_record_header_t *hdr =
        (const emb_ring_record_header_t *)(buf->data + offset);
    return *hdr;
}

emb_ring_read_result_t emb_ring_buffer_read_range(emb_ring_buffer_t *buf,
                                                   uint64_t start_ns,
                                                   uint64_t end_ns,
                                                   uint8_t *output,
                                                   size_t output_size)
{
    emb_ring_read_result_t result = {0};

    if (buf == NULL || output == NULL || output_size == 0) {
        return result;
    }

    // Track active readers so emb_ring_buffer_reset can detect concurrent use.
    atomic_fetch_add_explicit(&buf->active_readers, 1, memory_order_seq_cst);

    // Dekker-style check: after incrementing active_readers (seq_cst),
    // check if a reset is in progress. The seq_cst on both sides prevents
    // ARM64 store-buffer reordering that could let both sides miss each other.
    if (atomic_load_explicit(&buf->resetting, memory_order_seq_cst)) {
        atomic_fetch_sub_explicit(&buf->active_readers, 1, memory_order_release);
        return result;
    }

    // Snapshot the occupied region boundaries.
    uint64_t oldest_pos = atomic_load_explicit(&buf->oldest_pos, memory_order_acquire);
    const uint64_t write_pos = atomic_load_explicit(&buf->write_pos, memory_order_acquire);

    if (oldest_pos >= write_pos) {
        atomic_fetch_sub_explicit(&buf->active_readers, 1, memory_order_release);
        return result;
    }

    const size_t total_data = (size_t)(write_pos - oldest_pos);
    if (total_data > buf->capacity) {
        atomic_fetch_sub_explicit(&buf->active_readers, 1, memory_order_release);
        return result;
    }

    // ========================================================================
    // Phase 1: Scan live buffer headers to find the byte range to copy.
    //
    // THREE-LAYER CORRECTNESS MODEL:
    //
    // 1. PRIMARY (write_pos): scan_pos never advances past write_pos. This
    //    prevents reading uncommitted records. The record_size > (write_pos -
    //    scan_pos) check catches corrupted frame_count values that would
    //    extend past committed data.
    //
    // 2. EVICTION SAFETY (oldest_pos + seq_cst fence): Before and after
    //    reading each header, we check whether oldest_pos has advanced past
    //    our scan_pos. The seq_cst fence in the write path guarantees that
    //    if we observe oldest_pos unchanged, the data at our position has
    //    not been overwritten. If oldest_pos has advanced, we skip forward.
    //
    // 3. ADVISORY (seqlock seq field): The odd-seq check (hdr.seq & 1)
    //    provides defense-in-depth torn-read detection, but the read path
    //    does NOT rely on a full seqlock acquire/release handshake for data
    //    consistency. It is a belt-and-suspenders signal: if we happen to
    //    read a header mid-write, the odd seq causes us to stop scanning
    //    rather than parse garbage.
    //
    // Records between oldest_pos and write_pos are committed (even seq, stable
    // data). The writer only writes at write_pos. The seq_cst fence in the
    // write path guarantees that if we observe oldest_pos unchanged after
    // reading a header, the header data was not overwritten by a wrapping write.
    // ========================================================================

    uint64_t scan_pos = oldest_pos;

    // Skip records before start_ns.
    while (scan_pos + header_size <= write_pos) {
        // Check if the writer evicted past our position.
        uint64_t current_oldest = atomic_load_explicit(&buf->oldest_pos, memory_order_acquire);
        if (current_oldest > scan_pos) {
            scan_pos = current_oldest;
            continue;
        }

        emb_ring_record_header_t hdr = read_live_header(buf, scan_pos);

        // Re-check oldest_pos after reading. The seq_cst fence in the writer
        // guarantees that if oldest_pos hasn't advanced past us, the data at
        // our position has not been overwritten.
        current_oldest = atomic_load_explicit(&buf->oldest_pos, memory_order_acquire);
        if (current_oldest > scan_pos) {
            scan_pos = current_oldest;
            continue;
        }

        if (hdr.seq & 1) { goto done; }
        const size_t fc = hdr.frame_count;
        const size_t rsize = record_size(fc);
        if (rsize > (size_t)(write_pos - scan_pos)) { goto done; }

        if (hdr.timestamp_ns >= start_ns) { break; }
        scan_pos += rsize;
    }

    uint64_t copy_start = scan_pos;

    // Find end of matching range, counting records as we go.
    size_t scan_record_count = 0;
    while (scan_pos + header_size <= write_pos) {
        uint64_t current_oldest = atomic_load_explicit(&buf->oldest_pos, memory_order_acquire);
        if (current_oldest > scan_pos) {
            // Record evicted. Restart from new oldest position.
            copy_start = current_oldest;
            scan_pos = current_oldest;
            scan_record_count = 0;
            continue;
        }

        emb_ring_record_header_t hdr = read_live_header(buf, scan_pos);

        current_oldest = atomic_load_explicit(&buf->oldest_pos, memory_order_acquire);
        if (current_oldest > scan_pos) {
            // Record evicted. Restart from new oldest position.
            copy_start = current_oldest;
            scan_pos = current_oldest;
            scan_record_count = 0;
            continue;
        }

        if (hdr.seq & 1) { break; }
        const size_t fc = hdr.frame_count;
        const size_t rsize = record_size(fc);
        if (rsize > (size_t)(write_pos - scan_pos)) { break; }

        if (hdr.timestamp_ns > end_ns) { break; }
        scan_pos += rsize;
        scan_record_count++;
    }

    const uint64_t copy_end = scan_pos;

    if (copy_end <= copy_start) {
        goto done;
    }

    // ========================================================================
    // Phase 2: Targeted copy of just the matching range.
    // ========================================================================

    size_t copy_size = (size_t)(copy_end - copy_start);
    if (copy_size > output_size) {
        copy_size = output_size;
    }

    memcpy(output, buf->data + (copy_start % buf->capacity), copy_size);

    // ========================================================================
    // Phase 3: Post-copy validation.
    //
    // Re-check oldest_pos. If it hasn't advanced into our copy range, all
    // records are intact. If it has, records from post_oldest onward are
    // guaranteed stable (the writer only overwrites behind oldest_pos), so
    // we can compute the skip offset directly without per-record torn-read
    // checks.
    // ========================================================================

    uint64_t post_oldest = atomic_load_explicit(&buf->oldest_pos, memory_order_acquire);

    // Fast path: no eviction reached our copy range, so all records intact.
    if (post_oldest <= copy_start) {
        result.records_offset = 0;
        if (copy_size < (size_t)(copy_end - copy_start)) {
            // Output was truncated. Recount records that actually fit.
            size_t local_offset = 0;
            size_t fitted_count = 0;
            while (local_offset + header_size <= copy_size) {
                const emb_ring_record_header_t *hdr =
                    (const emb_ring_record_header_t *)(output + local_offset);
                const size_t rsize = record_size(hdr->frame_count);
                if (rsize > copy_size - local_offset) { break; }
                fitted_count++;
                local_offset += rsize;
            }
            result.record_count = fitted_count;
            result.total_bytes = local_offset;
        } else {
            result.record_count = scan_record_count;
            result.total_bytes = copy_size;
        }
        goto done;
    }

    // Eviction advanced into our copy range. Records from post_oldest onward
    // are stable (the writer hasn't touched them), so skip the evicted prefix
    // and count the remaining records.
    size_t evicted = (size_t)(post_oldest - copy_start);
    if (evicted >= copy_size) {
        goto done;
    }

    {
        size_t local_offset = evicted;
        size_t record_count = 0;

        while (local_offset + header_size <= copy_size) {
            const emb_ring_record_header_t *hdr =
                (const emb_ring_record_header_t *)(output + local_offset);
            if (hdr->seq & 1) { break; }
            const size_t fc = hdr->frame_count;
            const size_t rsize = record_size(fc);
            if (rsize > copy_size - local_offset) { break; }
            if (hdr->timestamp_ns > end_ns) { break; }
            record_count++;
            local_offset += rsize;
        }

        result.records_offset = evicted;
        result.record_count = record_count;
        result.total_bytes = local_offset - evicted;
    }

done:
    atomic_fetch_sub_explicit(&buf->active_readers, 1, memory_order_release);
    return result;
}

#endif /* !TARGET_OS_WATCH */
