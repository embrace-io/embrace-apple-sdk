//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#include "emb_ring_buffer.h"

#if !TARGET_OS_WATCH

#include <mach/mach.h>
#include <mach/vm_map.h>
#include <stdlib.h>
#include <string.h>

// Internal record header layout (stored in the ring buffer).
typedef struct {
    _Atomic uint32_t seq;  // Seqlock: odd = writing, even = stable.
    uint32_t frame_count;  // Number of frames in this record.
    uint64_t timestamp_ns; // Monotonic timestamp.
} emb_ring_record_header_t;

static const size_t header_size = sizeof(emb_ring_record_header_t);
static const size_t frame_size = sizeof(((emb_ring_record_t *)0)->frames[0]);
static const size_t unbelievable_frame_count = 1000000;

/// Calculate the size of a record with the given number of frames.
/// This will work out to the header size + 8 bytes per frame.
static inline size_t record_size(size_t frame_count)
{
    return header_size + frame_size * frame_count;
}

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
 
    // Sanity-check: VM_FLAGS_FIXED should guarantee the address didn't move.
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

bool emb_ring_buffer_write(emb_ring_buffer_t *buf,
                           uint64_t timestamp_ns,
                           const uintptr_t *frames,
                           size_t frame_count)
{
    if (buf == NULL || frames == NULL || frame_count > unbelievable_frame_count) {
        return false;
    }

    // Record size for the requested frame count.
    size_t record_size_needed = record_size(frame_count);

    // A single record must fit within the buffer capacity.
    // Should never happen since we check against unbelievable_frame_count,
    // but good just in case a future change allows it to slip through.
    if (record_size_needed > buf->capacity) {
        return false;
    }

    // Current write position (monotonically increasing byte offset).
    uint64_t write_pos = atomic_load_explicit(&buf->write_pos, memory_order_relaxed);
    uint64_t oldest_pos = atomic_load_explicit(&buf->oldest_pos, memory_order_acquire);

    // Evict old records that would be overlapped by this write.
    // The loop condition: oldest_pos + capacity < write_pos + record_size
    // This means the oldest record would be overwritten.
    while (oldest_pos + buf->capacity < write_pos + record_size_needed) {
        // Read the header of the oldest record to determine its size.
        size_t offset = oldest_pos % buf->capacity;
        emb_ring_record_header_t *old_header = (emb_ring_record_header_t *)(buf->data + offset);

        // Read frame_count (relaxed is safe: we're the single writer and this
        // is an old committed record).
        size_t old_frame_count = old_header->frame_count;

        // Advance oldest_pos past this record.
        oldest_pos += record_size(old_frame_count);

        // Publish the new oldest_pos.
        atomic_store_explicit(&buf->oldest_pos, oldest_pos, memory_order_release);
    }

    // Now that space is guaranteed, mark the record as "writing" via seqlock.
    size_t offset = write_pos % buf->capacity;
    emb_ring_record_header_t *header = (emb_ring_record_header_t *)(buf->data + offset);

    // Set seq to odd (writing).
    atomic_store_explicit(&header->seq, buf->next_seq | 1, memory_order_release);

    // Copy frame data into the buffer.
    uintptr_t *dest_frames = (uintptr_t *)(header + 1);
    memcpy(dest_frames, frames, frame_count * sizeof(*dest_frames));

    // Write the header fields (frame_count and timestamp).
    header->frame_count = (uint32_t)frame_count;
    header->timestamp_ns = timestamp_ns;

    // Seal the seqlock (transition to even = stable).
    atomic_store_explicit(&header->seq, buf->next_seq, memory_order_release);

    // Advance write_pos by the actual record size.
    atomic_store_explicit(&buf->write_pos, write_pos + record_size(frame_count), memory_order_release);

    // Increment the seqlock counter for the next write.
    buf->next_seq += 2;

    return true;
}

typedef struct {
    uint64_t start;
    uint64_t end;
    size_t count;
} buffer_range;

static buffer_range find_range(const emb_ring_buffer_t *buf,
                               uint64_t low_pos,
                               uint64_t high_pos,
                               uint64_t start_ns,
                               uint64_t end_ns)
{
    const buffer_range not_found = {0};
    const size_t capacity = buf->capacity;
    uint8_t *data = buf->data;
    buffer_range range = {0};
    uint64_t pos = low_pos;

    // Find start (leading edge of first record where time >= start_ns)
    while (pos < high_pos) {
        size_t offset = pos % capacity;
        emb_ring_record_header_t *header = (emb_ring_record_header_t *)(data + offset);
        uint64_t timestamp_ns = header->timestamp_ns;
        size_t frame_count = header->frame_count;

        if (frame_count > unbelievable_frame_count) {
            return not_found;
        }

        if (timestamp_ns >= start_ns) {
            break;
        }

        pos += record_size(frame_count);
    }

    if(pos >= high_pos) {
        return not_found;
    }
    range.start = pos;

    // Find end (trailing edge of last record where time <= end_ns)
    while (pos < high_pos) {
        size_t offset = pos % capacity;
        emb_ring_record_header_t *header = (emb_ring_record_header_t *)(data + offset);
        uint64_t timestamp_ns = header->timestamp_ns;
        size_t frame_count = header->frame_count;

        if (frame_count > unbelievable_frame_count) {
            return not_found;
        }
        if (timestamp_ns < start_ns) {
            break;
        }

        if (timestamp_ns > end_ns) {
            break;
        }
        range.count++;

        pos += record_size(frame_count);
    }
    range.end = pos;
    return range;
}

emb_ring_read_result_t emb_ring_buffer_read_range(const emb_ring_buffer_t *buf,
                                                   uint64_t start_ns,
                                                   uint64_t end_ns)
{
    emb_ring_read_result_t result = {NULL, 0};

    if (buf == NULL) {
        return result;
    }

    const uint64_t initial_start_pos = atomic_load_explicit(&buf->oldest_pos, memory_order_acquire);
    const uint64_t initial_end_pos = atomic_load_explicit(&buf->write_pos, memory_order_acquire);

    if (initial_start_pos >= initial_end_pos) {
        // Buffer is empty.
        return result;
    }
    
    buffer_range range = find_range(buf, initial_start_pos, initial_end_pos, start_ns, end_ns);

    const uint64_t snapshot_start_pos = atomic_load_explicit(&buf->oldest_pos, memory_order_acquire);
    const uint64_t snapshot_end_pos = atomic_load_explicit(&buf->write_pos, memory_order_acquire);
    
    if(snapshot_start_pos != initial_start_pos || snapshot_end_pos != initial_end_pos) {
        // Torn read while computing range, so find it again.
        // This is safe because we have only one periodic writer, so we won't get torn again.
        range = find_range(buf, snapshot_start_pos, snapshot_end_pos, start_ns, end_ns);
    }

    if (range.count == 0) {
        return result;
    }

    // Allocate space for record array + raw data.
    const size_t record_array_byte_count = range.count * sizeof(emb_ring_record_t);
    const size_t data_byte_count = range.end - range.start;
    if (data_byte_count > buf->capacity) {
        // If the write frequency invariant is violated and we tear more than once in a bad way, we'll catch it here.
        return result;
    }
    uint8_t *allocation = malloc(record_array_byte_count + data_byte_count);
    if (allocation == NULL) {
        return result;
    }

    emb_ring_record_t *records = (emb_ring_record_t *)allocation;
    uint8_t *data_region = allocation + record_array_byte_count;

    // Copy the raw data in one memcpy (safe due to double-mapping).
    memcpy(data_region, buf->data + range.start % buf->capacity, data_byte_count);

    const uint64_t current_start_pos = atomic_load_explicit(&buf->oldest_pos, memory_order_acquire);
    uint64_t pos = 0;
    if (current_start_pos > range.start) {
        // Data at the front was evicted during the copy, so exclude it.
        const uint64_t eviction_delta = current_start_pos - range.start;
        if (eviction_delta >= (uint64_t)data_byte_count) {
            // The entire copied window is stale.
            free(allocation);
            return result;
        }
        pos = (size_t)eviction_delta;
    }

    size_t valid_count = 0;

    while (pos < data_byte_count) {
        if (pos + header_size > data_byte_count) {
            break;
        }
        const emb_ring_record_header_t *header = (emb_ring_record_header_t *)(data_region + pos);
        const uint64_t seq = header->seq;
        const size_t frame_count = header->frame_count;

        if ((seq & 1) != 0) {
            // An odd seq means that a write was in progress when memcpy reached this header.
            // Any data after this point is unusable.
            break;
        }

        const size_t rsize = record_size(frame_count);
        if (frame_count > unbelievable_frame_count || rsize > data_byte_count - pos) {
            // Corrupt or torn frame_count; stop parsing.
            break;
        }

        records[valid_count].timestamp_ns = header->timestamp_ns;
        records[valid_count].frame_count = frame_count;
        records[valid_count].frames = (const uintptr_t *)(header + 1);
        valid_count++;

        // Advance to next record.
        pos += rsize;
    }

    result.records = records;
    result.count = valid_count;
    return result;
}

void emb_ring_read_result_free(emb_ring_read_result_t *result)
{
    if (result != NULL && result->records != NULL) {
        free(result->records);
        result->records = NULL;
        result->count = 0;
    }
}

#endif /* !TARGET_OS_WATCH */
