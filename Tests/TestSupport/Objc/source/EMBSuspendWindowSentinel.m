//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import "EMBSuspendWindowSentinel.h"

#import <pthread.h>
#import <stdatomic.h>

// `malloc_logger` is a private-but-exported libmalloc global. When non-NULL, libmalloc invokes it on
// every allocation/free (this is the hook Instruments' allocation tracking uses). We declare it here
// because it is not in a public header.
typedef void(malloc_logger_t)(uint32_t type, uintptr_t arg1, uintptr_t arg2, uintptr_t arg3, uintptr_t result,
                              uint32_t num_hot_frames_to_skip);
extern malloc_logger_t *malloc_logger;

static malloc_logger_t *emb_previous_logger = NULL;
static _Atomic(int) emb_armed = 0;
static _Atomic(int) emb_in_window = 0;
static _Atomic(uint64_t) emb_violations = 0;
static pthread_t emb_window_thread;  // guarded by emb_in_window ordering

// Runs inside libmalloc, possibly while the allocator lock is held. MUST NOT allocate or lock —
// only lock-free atomics here, or we become the very deadlock we are testing for.
static void emb_allocation_observer(uint32_t type, uintptr_t arg1, uintptr_t arg2, uintptr_t arg3, uintptr_t result,
                                    uint32_t num_hot_frames_to_skip)
{
    if (atomic_load_explicit(&emb_in_window, memory_order_acquire)) {
        if (pthread_equal(pthread_self(), emb_window_thread)) {
            atomic_fetch_add_explicit(&emb_violations, 1, memory_order_relaxed);
        }
    }
}

void EMBSuspendWindowSentinelArm(void)
{
    if (atomic_exchange_explicit(&emb_armed, 1, memory_order_acq_rel)) {
        return;  // already armed
    }
    emb_previous_logger = malloc_logger;
    malloc_logger = emb_allocation_observer;
}

void EMBSuspendWindowSentinelDisarm(void)
{
    if (!atomic_exchange_explicit(&emb_armed, 0, memory_order_acq_rel)) {
        return;  // not armed
    }
    malloc_logger = emb_previous_logger;
    emb_previous_logger = NULL;
    atomic_store_explicit(&emb_in_window, 0, memory_order_release);
}

void EMBSuspendWindowSentinelBeginWindow(void)
{
    emb_window_thread = pthread_self();
    atomic_store_explicit(&emb_in_window, 1, memory_order_release);
}

void EMBSuspendWindowSentinelEndWindow(void) { atomic_store_explicit(&emb_in_window, 0, memory_order_release); }

uint64_t EMBSuspendWindowSentinelViolationCount(void)
{
    return atomic_load_explicit(&emb_violations, memory_order_relaxed);
}

void EMBSuspendWindowSentinelResetViolations(void) { atomic_store_explicit(&emb_violations, 0, memory_order_relaxed); }
