//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

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

/// Ring buffer for profiling stack trace samples.
///
/// Single-writer, multiple-reader. The write path is async-safe (no heap
/// allocation, no locks). Readers are not async-safe and may retry.
///
/// Uses a VM double-mapping trick: the same physical pages are mapped at two
/// contiguous virtual addresses. A write that straddles the end of the buffer
/// wraps to the beginning transparently, with no special-case code.
///
/// DESIGN ASSUMPTIONS:
/// - There will only ever be one writer, and multiple concurrent readers.
/// - The writer will not write often enough to cause more than one torn read for any given reader.
///   Officially, the minimum is 1ms between writes, even though it could likely handle tighter cadence.
typedef struct {
    uint8_t *data;               // Double-mapped virtual region (2 × capacity).
    size_t capacity;             // Usable buffer size in bytes (page-aligned).
    uint64_t next_seq;           // Writer-local seqlock counter (single-writer).
    _Atomic uint64_t write_pos;  // Monotonically increasing write position.
    _Atomic uint64_t oldest_pos; // Position of the oldest surviving record.
} emb_ring_buffer_t;

/// Create a ring buffer.
///
/// This function is not async-safe.
///
/// @param capacity_bytes Minimum usable capacity; rounded up to a page boundary.
/// @return A newly allocated buffer, or NULL on failure.
emb_ring_buffer_t *emb_ring_buffer_create(size_t capacity_bytes);

/// Destroy a ring buffer and release all VM and heap resources.
///
/// This function is not async-safe.
///
/// Safe to call with NULL.
void emb_ring_buffer_destroy(emb_ring_buffer_t *buf);

/// Write a record to the ring buffer. Evicts old records if necessary.
///
/// Copies the frame data into the buffer and makes it visible to readers.
///
/// This function is async-safe.
///
/// Invariants:
/// - Only one concurrent writer
/// - Minimum 1ms between writes
/// - Less than 1 million stack trace frames
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

/// Consumer-facing record (returned by read functions).
typedef struct {
    uint64_t timestamp_ns;   // Monotonic timestamp (nanoseconds).
    size_t frame_count;      // Number of frames in this sample.
    const uintptr_t *frames; // Frame addresses (points into allocation).
} emb_ring_record_t;

/// Result from a read operation.
typedef struct {
    emb_ring_record_t *records; // Array of records.
    size_t count;               // Number of valid records.
} emb_ring_read_result_t;

/// Read records from the ring buffer within a time range.
///
/// Returns records with timestamps in the range [start_ns, end_ns].
/// Use end_ns = UINT64_MAX to read up to the current write position.
///
/// Returns a single allocation containing the record array and frame data.
/// Free with emb_ring_read_result_free().
///
/// This function is not async-safe.
///
/// @param buf The ring buffer.
/// @param start_ns Start timestamp (inclusive, nanoseconds).
/// @param end_ns End timestamp (inclusive, nanoseconds). Use UINT64_MAX for "up to now".
/// @return Result containing matching records. count=0 if empty, out of range, or buf is NULL.
emb_ring_read_result_t emb_ring_buffer_read_range(const emb_ring_buffer_t *buf,
                                                   uint64_t start_ns,
                                                   uint64_t end_ns);

/// Free a buffer read result.
///
/// This function is not async-safe.
///
/// Safe to call with a zeroed result (records=NULL).
void emb_ring_read_result_free(emb_ring_read_result_t *result);

#ifdef __cplusplus
}
#endif

#endif /* !TARGET_OS_WATCH */

#endif /* emb_ring_buffer_h */
