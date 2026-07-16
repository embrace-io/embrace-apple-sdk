//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

/// File-backed persistence for the profiling ring buffer.
///
/// `emb_profile_store` owns a per-session file and the memory mapping over it, and
/// hands back an `emb_ring_buffer_t` (via `emb_ring_buffer_attach`) wired to the
/// mapped data region + a mapped footer control block. The sampler writes into that
/// ring buffer exactly as it does for an in-memory buffer; the kernel flushes the
/// dirty `MAP_SHARED` pages to the file, so samples survive abrupt process death and
/// can be recovered on the next launch.
///
/// See `PROFILING-DISK-FORMAT.md` for the on-disk format. Recovery (reading a
/// previous session's file) lives in this unit too (added in a later step); creation
/// and the live write path are here.
///
/// NONE of this is async-safe — create/destroy/recovery all run off the hot path.

#ifndef emb_profile_store_h
#define emb_profile_store_h

#include <TargetConditionals.h>

#if !TARGET_OS_WATCH

#include <stdint.h>
#include <stddef.h>

#include "emb_ring_buffer.h"

#ifdef __cplusplus
extern "C" {
#endif

#define EMB_PROFILE_FILE_MAGIC 0x454D422D50524F46ULL  // "EMB-PROF" — version-free, also an endianness marker
#define EMB_PROFILE_FORMAT_VER 1u                      // first real version
// format_version == 0 is RESERVED FOREVER as "disregard this file": written transiently while a file is
// mid-mutation (create/reset) and as the clean-shutdown / finalized tombstone. Because the identity
// layout is frozen, version 0 means "ignore" regardless of any future format change.
#define EMB_PROFILE_FORMAT_INVALID 0u

/// Write-once static descriptor (written at create).
typedef struct {
    uint64_t created_uptime_ns;   // CLOCK_MONOTONIC_RAW at creation
    uint64_t created_wall_ns;     // wall clock at creation (session correlation)
    uint8_t  session_id[16];      // opaque 128-bit id supplied by the caller
    uint64_t image_table_offset;  // reserved for a future image table (symbolication); always 0 in v1
    uint64_t image_table_bytes;   // reserved; always 0 in v1 (see PROFILING-DISK-FORMAT.md appendix)
} emb_profile_descriptor_t;

/// FROZEN identity — the LAST bytes of the file. Same layout in every format version, forever.
/// Discovered via fstat + read(EOF − sizeof(emb_profile_ident_t)) — placing it at EOF (not the front)
/// lets a reader find it without knowing the file's size or format version first, so any other field
/// can grow or move between versions (see PROFILING-DISK-FORMAT.md §2.1).
typedef struct {
    uint64_t magic;           // EMB_PROFILE_FILE_MAGIC
    uint64_t format_version;  // selects the parser for everything else; 0 = "disregard this file"
} emb_profile_ident_t;
_Static_assert(sizeof(emb_profile_ident_t) == 16, "frozen identity must stay 16 bytes, forever");

/// Version-specific trailer — sits immediately before the identity struct. v1 layout.
typedef struct {
    uint64_t footer_offset;       // == data_capacity; where the footer begins
    uint64_t data_capacity;       // ring data region size in bytes (page-aligned)
    uint32_t page_size;           // page size used at creation
    uint16_t record_header_bytes; // sizeof(emb_ring_record_header_t), validated on recovery
    uint16_t pointer_bytes;       // sizeof(uintptr_t) == 8
    uint32_t footer_bytes;        // total footer size
    uint32_t trailer_bytes;       // on-disk size of THIS version's trailer, so a newer build can step
                                  // back from the identity to it without assuming its own sizeof
} emb_profile_trailer_v1_t;

/// Opaque store handle. Owns the fd, the address-space reservation/mapping, the mapped
/// control block, and the attached ring buffer.
typedef struct emb_profile_store emb_profile_store_t;

/// Create a fresh file-backed store at `path` (the caller-injected directory must already
/// exist; the file is created/truncated). On success, returns a store whose ring buffer
/// (`emb_profile_store_buffer`) is ready for the sampler.
///
/// @param path          Filesystem path for this session's file.
/// @param capacity_bytes Minimum data-region capacity; rounded up to a page boundary.
/// @param session_id    Opaque 128-bit session id recorded in the descriptor.
/// @param errno_out     On failure, receives `errno` (or 0 for a non-errno failure). May be NULL.
/// @return A new store, or NULL on failure.
emb_profile_store_t *emb_profile_store_create(const char *path,
                                              size_t capacity_bytes,
                                              const uint8_t session_id[16],
                                              int *errno_out);

/// The ring buffer wired to this store's mapped data region. Owned by the store; do not
/// destroy it directly — use `emb_profile_store_destroy`.
emb_ring_buffer_t *emb_profile_store_buffer(emb_profile_store_t *store);

/// Clear the buffer for reuse within the same process (e.g. a same-capacity restart),
/// reusing the same file. Transactional: format_version → 0, memset the data region +
/// reset positions, format_version → 1. A crash mid-reset leaves version 0 so recovery
/// disregards the half-cleared file. Returns false if a concurrent reader blocked the
/// reset (the file is left intact and valid). NOT async-safe.
bool emb_profile_store_reset(emb_profile_store_t *store);

/// Mark the file cleanly finalized: write the format_version → 0 tombstone, so recovery
/// reports nothing for it (its samples were already drained live). Does not delete the
/// file (Embrace owns deletion). Call after the writer has stopped. NOT async-safe.
void emb_profile_store_finalize(emb_profile_store_t *store);

/// `msync(MS_ASYNC)` the mapped data + footer. Not needed to survive process death (crash, Jetsam
/// kill) — the kernel's page cache owns the dirty `MAP_SHARED` pages independent of the process and
/// writes them back regardless. Call this from willResignActive/didEnterBackground/willTerminate to
/// also protect against uncontrolled terminations such as power loss / kernel panic while the app is
/// suspended, by narrowing the window recently-captured samples sit unwritten in memory. Cheap,
/// non-blocking, off the hot path. NOT async-safe (call from the main/notification thread on
/// background/terminate).
void emb_profile_store_flush(emb_profile_store_t *store);

/// Tear down the store: destroy the ring buffer wrapper, unmap the reservation, close the
/// file. Does not delete the file (Embrace owns deletion), and does not itself force a sync — the
/// kernel writes back the MAP_SHARED pages regardless of process death. Call `emb_profile_store_flush`
/// from willResignActive/didEnterBackground/willTerminate beforehand to also protect against
/// uncontrolled terminations such as power loss / kernel panic while the app is suspended. Safe to
/// call with NULL.
void emb_profile_store_destroy(emb_profile_store_t *store);

// MARK: - Recovery (read-only)

/// Outcome of attempting to recover a previous session's file.
typedef enum {
    EMB_PROFILE_RECOVER_OK = 0,        // parsed; `emit` was invoked once per recovered record
    EMB_PROFILE_RECOVER_FINALIZED,     // cleanly finalized (format_version 0) — nothing to recover
    EMB_PROFILE_RECOVER_NOT_OURS,      // magic mismatch — not one of our files
    EMB_PROFILE_RECOVER_UNSUPPORTED,   // format_version this build doesn't understand
    EMB_PROFILE_RECOVER_CORRUPT,       // trailer / control-block validation failed → discard
    EMB_PROFILE_RECOVER_IO_ERROR,      // open / fstat / read / mmap failed
} emb_profile_recover_status_t;

/// Callback invoked once per recovered record, in chronological order.
/// `frames` points into a temporary mapping valid only for the duration of the call —
/// copy what you need; do not retain it.
typedef void (*emb_profile_record_cb)(void *ctx,
                                      uint64_t timestamp_ns,
                                      uint8_t thread_state,
                                      uint8_t flags,
                                      const uintptr_t *frames,
                                      uint32_t frame_count);

/// Recover a previous session's file. **Strictly read-only** — never writes, tombstones, or
/// deletes the file (Embrace owns deletion). Reads the frozen identity (version gate: 0 →
/// FINALIZED, unknown → NOT_OURS/UNSUPPORTED), validates the v1 trailer and control block
/// (discard on inconsistency), then double-maps the data region and walks records from
/// oldest_pos to write_pos — stopping on a torn tail (odd seq), a zeroed/unflushed page
/// (frame_count == 0), garbage (frame_count > MAX), or a record overrunning committed data.
/// Each valid record is delivered via `emit`.
///
/// NOT async-safe. Intended to run off the main thread at launch.
emb_profile_recover_status_t emb_profile_recover(const char *path,
                                                 emb_profile_record_cb emit,
                                                 void *ctx);

/// Classification of a file from a cheap peek at its frozen identity only (no record walk).
typedef enum {
    EMB_PROFILE_PEEK_RECOVERABLE = 0,  // ours, format_version != 0 — has (or may have) records
    EMB_PROFILE_PEEK_FINALIZED,        // ours, format_version 0 — cleanly stopped, nothing to recover
    EMB_PROFILE_PEEK_NOT_OURS,         // a readable regular file whose magic doesn't match — not ours
    EMB_PROFILE_PEEK_INDETERMINATE,    // couldn't open/stat/read (e.g. locked under data protection at
                                       // launch, or a transient I/O error) — may be ours; retry later
} emb_profile_peek_status_t;

/// Cheaply classify a candidate file by reading ONLY the 16-byte frozen identity at EOF (open +
/// fstat + one pread). Lets a caller enumerate a directory and decide what to recover/delete without
/// mapping or walking any records. Read-only; never modifies the file. NOT async-safe.
///
/// A file that can't be opened/stat'd/read returns INDETERMINATE (not NOT_OURS): it may be one of ours
/// that is temporarily unreadable (e.g. still locked under data protection at launch), so the caller
/// should retry it on a later launch rather than discard it. Retries EINTR internally.
emb_profile_peek_status_t emb_profile_peek(const char *path);

#ifdef __cplusplus
}
#endif

#endif /* !TARGET_OS_WATCH */

#endif /* emb_profile_store_h */
