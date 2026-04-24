//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
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

#include <stdbool.h>
#include <stdatomic.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint8_t *data;               // Double-mapped virtual region (2 × capacity).
    size_t capacity;             // Usable buffer size in bytes (page-aligned).
    uint64_t next_seq;           // Writer-local seqlock counter (single-writer).
    _Atomic uint64_t write_pos;  // Monotonically increasing write position.
    _Atomic uint64_t oldest_pos; // Position of the oldest surviving record.
    _Atomic uint32_t active_readers; // Number of concurrent read_range calls (for reset safety).
    _Atomic bool resetting;      // True while reset is in progress.
                                 // Uses Dekker-style mutual exclusion with active_readers:
                                 // both sides use seq_cst to prevent ARM64 store-buffer
                                 // reordering. See emb_ring_buffer_reset and read_range.
} emb_ring_buffer_t;

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
    uint32_t seq;          // Internal seqlock value (ignore).
    uint32_t frame_count;  // Number of frames following this header.
    uint64_t timestamp_ns; // Monotonic timestamp (nanoseconds).
} emb_ring_record_header_t;

// The record layout assumes 64-bit pointers (uintptr_t == 8 bytes).
// The Swift layer reads frame data as UInt (also 8 bytes on 64-bit).
// Catch any hypothetical 32-bit platform at compile time.
_Static_assert(sizeof(uintptr_t) == 8,
               "Ring buffer record layout requires 64-bit pointers");

/// Compute the total byte size of a record with the given frame count.
static inline size_t emb_ring_record_size(uint32_t frame_count) {
    return sizeof(emb_ring_record_header_t) + (size_t)frame_count * sizeof(uintptr_t);
}

/// Result from a read operation.
typedef struct {
    size_t records_offset; // Offset in bytes to the first matching record.
    size_t record_count;   // Number of matching records written to the output buffer.
    size_t total_bytes;    // Total size in bytes of the matching record set.
} emb_ring_read_result_t;

/// Create a ring buffer.
///
/// This function is NOT async-safe.
///
/// @param capacity_bytes Minimum usable capacity; rounded up to a page boundary.
/// @return A newly allocated buffer, or NULL on failure.
emb_ring_buffer_t *emb_ring_buffer_create(size_t capacity_bytes);

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
/// @param frame_count Number of frames in the array. Must not exceed UINT32_MAX.
/// @return true if the write succeeded, false if buf or frames is NULL.
bool emb_ring_buffer_write(emb_ring_buffer_t *buf,
                           uint64_t timestamp_ns,
                           const uintptr_t *frames,
                           size_t frame_count);

/// Read records from the ring buffer within a time range.
///
/// Scans the live buffer to locate the matching time range, then copies only
/// the matching records into the caller-provided output buffer. This avoids
/// copying the entire ring buffer contents for small time ranges.
///
/// Walk the results starting at `output + result.offset`, casting to
/// `emb_ring_record_header_t *`, reading `frame_count`, advancing by
/// `emb_ring_record_size(frame_count)`, and repeating for `result.count`
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
/// @return Result containing count and total bytes written. count=0 if empty,
///         out of range, buf is NULL, output is NULL, or a reset is in progress.
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
