//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

/// Lock-free ring buffer for holding stack trace samples.
///
/// Single-writer, multiple-reader. All functions are async-safe except for
/// create and destroy.
///
/// In order to keep memory churn to a minimum, a caller must pass in a buffer
/// to receive the data when reading. The caller (in our case, ProfilingEngine)
/// maintains its own persistent read buffer of the same size as this ring buffer,
/// and then in turn provides smaller allocations to its callers, with its own
/// concurrency guarantees.
///
/// CAPACITY GUIDANCE:
/// The buffer is designed for records much smaller than the total capacity.
/// Individual records (header + frames) should be less than 25% of the
/// buffer size to guarantee safe reads with a write interval down to 1ms.
/// Concurrent reads may see torn data if a record size approaches the
/// buffer capacity and/or frequency is too high, because the writer could
/// overwrite the record mid-read.
///
/// DESIGN ASSUMPTIONS:
/// - There will only ever be one writer, and multiple concurrent readers.
/// - The writer will not write often enough to cause more than one torn read for any given reader.
///   Officially, the minimum is 1ms between writes, even though it could likely handle tighter cadence.

#ifndef emb_ring_buffer_h
#define emb_ring_buffer_h

#include <TargetConditionals.h>

#if !TARGET_OS_WATCH

#include <mach/kern_return.h>
#include <mach/thread_info.h>
#include <stdbool.h>
#include <stdatomic.h>
#include <stddef.h>
#include <stdint.h>

/// Status codes returned by emb_ring_buffer_write.
typedef enum {
    EMB_RING_WRITE_OK                  = 0,
    EMB_RING_WRITE_BAD_ARGS            = 1,
    EMB_RING_WRITE_RECORD_TOO_LARGE    = 2,
    EMB_RING_WRITE_CORRUPTION_DETECTED = 3,
} emb_ring_write_status_t;

/// Status codes returned in emb_ring_read_result_t.
typedef enum {
    EMB_RING_READ_OK        = 0,
    EMB_RING_READ_BAD_ARGS  = 1,
    EMB_RING_READ_RESETTING = 2,
    EMB_RING_READ_EMPTY     = 3,
    EMB_RING_READ_TRUNCATED = 4,
} emb_ring_read_status_t;

#ifdef __cplusplus
extern "C" {
#endif

/// Control block holding the writer/reader positions. Relocated out of
/// emb_ring_buffer_t so it can be backed either by a small anonymous allocation
/// (in-memory buffers) or by a file-backed mapped footer page (persistent buffers,
/// PROFILING-DISK-FORMAT.md §3.1) — the same struct, only the backing differs.
typedef struct {
    _Atomic uint64_t write_pos;  // Monotonically increasing write position.
    _Atomic uint64_t oldest_pos; // Position of the oldest surviving record.
    uint64_t next_seq;           // Writer-local seqlock counter (single-writer).
    _Atomic uint32_t status_flags; // Reserved (file-backed lifecycle is signaled via the footer
                                 // format_version, not here — PROFILING-DISK-FORMAT.md §8).
} emb_ring_control_t;

typedef struct {
    uint8_t *data;               // Double-mapped virtual region (2 × capacity).
    size_t capacity;             // Usable buffer size in bytes (page-aligned).
    emb_ring_control_t *control; // write_pos / oldest_pos / next_seq (anon- or file-backed).
    bool owns_resources;         // true: this buffer owns `data` (vm) and `control` (heap) and frees
                                 // them on destroy. false: a file-backed store owns the mapping.
    _Atomic uint32_t active_readers; // Number of concurrent read_range calls (for reset safety).
    _Atomic bool resetting;      // True while reset is in progress.
                                 // Uses Dekker-style mutual exclusion with active_readers:
                                 // both sides use seq_cst to prevent ARM64 store-buffer
                                 // reordering. See emb_ring_buffer_reset and read_range.
} emb_ring_buffer_t;

/// Hard upper limit on stack frames per sample. Defined here (not in emb_sampler.h)
/// because the ring write path validates `frame_count` against it; emb_sampler.h
/// includes this header and consumes the value from here.
#define EMB_MAX_STACK_FRAMES 1024

/// Main-thread run state captured per sample (see THREAD-STATE.md). Values mirror
/// the Mach `TH_STATE_*` constants so the stored byte equals
/// `thread_basic_info.run_state`. 255 = "couldn't capture" — Mach never returns it.
typedef enum {
    EMB_THREAD_RUN_STATE_RUNNING         = 1,   // == TH_STATE_RUNNING
    EMB_THREAD_RUN_STATE_STOPPED         = 2,   // == TH_STATE_STOPPED
    EMB_THREAD_RUN_STATE_WAITING         = 3,   // == TH_STATE_WAITING
    EMB_THREAD_RUN_STATE_UNINTERRUPTIBLE = 4,   // == TH_STATE_UNINTERRUPTIBLE
    EMB_THREAD_RUN_STATE_HALTED          = 5,   // == TH_STATE_HALTED
    EMB_THREAD_RUN_STATE_UNKNOWN         = 255,  // thread_info failed / not captured
} emb_thread_run_state_t;
_Static_assert(EMB_THREAD_RUN_STATE_RUNNING == TH_STATE_RUNNING
            && EMB_THREAD_RUN_STATE_STOPPED == TH_STATE_STOPPED
            && EMB_THREAD_RUN_STATE_WAITING == TH_STATE_WAITING
            && EMB_THREAD_RUN_STATE_UNINTERRUPTIBLE == TH_STATE_UNINTERRUPTIBLE
            && EMB_THREAD_RUN_STATE_HALTED == TH_STATE_HALTED,
            "emb_thread_run_state_t must mirror TH_STATE_*");

/// Per-sample flag bits packed into the record header's `flags` byte. This is OUR
/// own layout, NOT raw `thread_basic_info.flags`: idle/swapped are remapped to
/// these bit positions and `truncated` is not a Mach flag.
enum {
    EMB_RECORD_FLAG_IDLE      = 1u << 0,  // thread is an idle thread   (from TH_FLAGS_IDLE)
    EMB_RECORD_FLAG_SWAPPED   = 1u << 1,  // thread is swapped out       (from TH_FLAGS_SWAPPED)
    EMB_RECORD_FLAG_TRUNCATED = 1u << 2,  // stack exceeded max_frames
};

/// Public facing view of the record header stored in the ring buffer.
/// We do this to simplify reading the records. It's expected that the caller would
/// then convert the retrieved records to a more suitable user-facing format.
///
/// Each record consists of this header followed by `frame_count` values of
/// type `uintptr_t` (the captured frame addresses). Use `emb_ring_record_size`
/// to compute the total byte size of a record.
///
/// The `seq` field is an internal seqlock value used for torn-read detection,
/// and callers should ignore it.
typedef struct {
    uint32_t seq;           // Internal seqlock value (ignore).
    uint16_t frame_count;   // Number of frames following this header (1..EMB_MAX_STACK_FRAMES).
    uint8_t  thread_state;  // emb_thread_run_state_t at capture time.
    uint8_t  flags;         // EMB_RECORD_FLAG_* bits (our packed layout).
    uint64_t timestamp_ns;  // Monotonic timestamp (nanoseconds).
} emb_ring_record_header_t;

// The record layout assumes 64-bit pointers (uintptr_t == 8 bytes).
// The Swift layer reads frame data as UInt (also 8 bytes on 64-bit).
// Catch any hypothetical 32-bit platform at compile time.
_Static_assert(sizeof(uintptr_t) == 8,
               "Ring buffer record layout requires 64-bit pointers");
// The header must stay exactly 16 bytes: seq(4) + frame_count(2) + thread_state(1)
// + flags(1) + timestamp_ns(8). The on-disk format (PROFILING-DISK-FORMAT.md §3.2)
// mirrors this byte-for-byte and the trailer records sizeof() for recovery.
_Static_assert(sizeof(emb_ring_record_header_t) == 16,
               "Ring buffer record header must stay 16 bytes");

/// Compute the total byte size of a record with the given frame count.
static inline size_t emb_ring_record_size(uint32_t frame_count) {
    return sizeof(emb_ring_record_header_t) + (size_t)frame_count * sizeof(uintptr_t);
}

/// Result from a read operation.
typedef struct {
    size_t records_offset;         // Offset in bytes to the first matching record.
    size_t record_count;           // Number of matching records written to the output buffer.
    size_t total_bytes;            // Total size in bytes of the matching record set.
    emb_ring_read_status_t status; // Status code describing the outcome.
} emb_ring_read_result_t;

/// Create a ring buffer.
///
/// This function is NOT async-safe.
///
/// @param capacity_bytes Minimum usable capacity; rounded up to a page boundary.
/// @param kr_out  On failure, receives the kern_return_t that caused the error. May be NULL.
/// @return A newly allocated buffer, or NULL on failure.
emb_ring_buffer_t *emb_ring_buffer_create(size_t capacity_bytes, kern_return_t *kr_out);

/// Create a ring buffer over caller-provided, externally-owned backing memory.
///
/// Used by `emb_profile_store` for file-backed buffers: the store builds the
/// double-mapped file region and the (mapped) control block, then attaches a ring
/// buffer over them. The returned buffer has `owns_resources == false`, so
/// `emb_ring_buffer_destroy` frees only the wrapper — never `data` or `control`
/// (the store owns and unmaps those).
///
/// This function does NOT modify `*control` — the caller sets the positions (0 for
/// a freshly truncated file; the persisted values for recovery).
///
/// This function is NOT async-safe.
///
/// @param data     Double-mapped region of 2×capacity bytes (lower half + aliased upper half).
/// @param capacity Page-aligned usable capacity in bytes (the data region size).
/// @param control  Caller-owned control block (anon or mapped).
/// @return A newly allocated buffer wrapper, or NULL on bad args / allocation failure.
emb_ring_buffer_t *emb_ring_buffer_attach(uint8_t *data, size_t capacity, emb_ring_control_t *control);

/// Destroy a ring buffer and release all VM and heap resources.
///
/// This function is NOT async-safe.
///
/// Safe to call with NULL.
void emb_ring_buffer_destroy(emb_ring_buffer_t *buf);

/// Reset a ring buffer, clearing all data and resetting positions.
///
/// The caller must ensure no concurrent writer is active.
///
/// Returns false if buf is NULL or if readers are active.
///
/// @return true if the buffer was successfully reset, false otherwise.
bool emb_ring_buffer_reset(emb_ring_buffer_t *buf);

/// Return the usable capacity of the ring buffer in bytes.
///
/// This is the page-aligned capacity, which may be larger than the value
/// passed to emb_ring_buffer_create.
///
/// This function is async-safe.
///
/// @param buf The ring buffer. Returns 0 if NULL.
/// @return Capacity in bytes, or 0 if buf is NULL.
size_t emb_ring_buffer_capacity(const emb_ring_buffer_t *buf);

/// Write a record to the ring buffer. Evicts old records if necessary.
///
/// Copies the frame data into the buffer and makes it visible to readers.
///
/// This function is async-safe.
///
/// Invariants:
/// - Only one concurrent writer
/// - Minimum 1ms between writes
///
/// @param buf The ring buffer.
/// @param timestamp_ns Monotonic timestamp (nanoseconds).
/// @param frames Array of frame addresses to copy.
/// @param frame_count Number of frames in the array. Stored as uint16, so must not exceed
///        UINT16_MAX. (The sampler, sole writer of persisted buffers, writes 1..EMB_MAX_STACK_FRAMES.)
/// @param thread_state emb_thread_run_state_t for the sampled thread at capture time.
/// @param flags EMB_RECORD_FLAG_* bits for this sample.
/// @return EMB_RING_WRITE_OK on success; EMB_RING_WRITE_BAD_ARGS if buf is NULL, frames is NULL with
///         a non-zero frame_count, or frame_count exceeds UINT16_MAX; EMB_RING_WRITE_RECORD_TOO_LARGE
///         if the record does not fit in the buffer; EMB_RING_WRITE_CORRUPTION_DETECTED if a corrupted
///         header was found during eviction.
emb_ring_write_status_t emb_ring_buffer_write(emb_ring_buffer_t *buf,
                                               uint64_t timestamp_ns,
                                               const uintptr_t *frames,
                                               size_t frame_count,
                                               uint8_t thread_state,
                                               uint8_t flags);

/// Read records from the ring buffer within a time range.
///
/// Scans the live buffer to locate the matching time range, then copies only
/// the matching records into the caller-provided output buffer. This avoids
/// copying the entire ring buffer contents for small time ranges.
///
/// Walk the results starting at `output + result.records_offset`, casting to
/// `emb_ring_record_header_t *`, reading `frame_count`, advancing by
/// `emb_ring_record_size(frame_count)`, and repeating for `result.record_count`
/// records.
///
/// The output buffer must be large enough to hold the matching records.
/// Using `emb_ring_buffer_capacity(buf)` bytes guarantees all possible
/// results fit. A smaller buffer will truncate the results.
///
/// Returns empty immediately if the buffer is currently being reset.
///
/// This function is async-safe.
///
/// @param buf The ring buffer.
/// @param start_ns Start timestamp (inclusive, nanoseconds).
/// @param end_ns End timestamp (inclusive, nanoseconds). Use UINT64_MAX for "up to now".
/// @param output Caller-provided output buffer.
/// @param output_size Size of the output buffer in bytes.
/// @return Result containing count, total bytes written, and a status code.
///         record_count=0 if empty, out of range, buf is NULL, output is NULL, or
///         a reset is in progress. Check result.status for the specific reason.
emb_ring_read_result_t emb_ring_buffer_read_range(emb_ring_buffer_t *buf,
                                                   uint64_t start_ns,
                                                   uint64_t end_ns,
                                                   uint8_t *output,
                                                   size_t output_size);

#ifdef __cplusplus
}
#endif

#endif /* !TARGET_OS_WATCH */

#endif /* emb_ring_buffer_h */
