//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#include "emb_sampler.h"

#if !TARGET_OS_WATCH

#include "emb_ring_buffer.h"
#include "emb_stack_walker.h"

#include <mach/mach_time.h>
#include <mach/thread_act.h>
#include <os/log.h>
#include <pthread.h>
#include <pthread/qos.h>
#include <stdatomic.h>
#include <stdlib.h>

static os_log_t g_profiling_log;

static inline os_log_t emb_profiling_log(void) {
    return g_profiling_log;
}

static const uint64_t NS_PER_MS = 1000000ULL;
static const int CAS_SUCCESS = 0;
static const int EMB_SAMPLER_STARTING_OR_STOPPING_MASK = EMB_SAMPLER_STARTING | EMB_SAMPLER_STOPPING;

static emb_ring_buffer_t *g_buffer;        // Note: owned by the caller, not us.
static pthread_t g_worker;
static _Atomic int g_state = EMB_SAMPLER_STOPPED;
static emb_sampler_config_t g_config;      // Config used to start the sampler.
static uintptr_t *g_stack_frames;          // Pre-allocated frame buffer.
static uint64_t g_interval_ticks;          // Target ticks between samples.
static uint64_t g_min_interval_ticks;      // Floor: smallest gap when recovering from drift.
static uint64_t g_max_interval_ticks;      // Ceiling: safeguard against huge sleeps.
static thread_t g_main_thread;             // Mach port, resolved once at start.
static const char *g_fault_reason;         // Human-readable fault reason (static string, never freed).

static thread_t g_main_mach_thread_cached = MACH_PORT_NULL;
static pthread_t g_main_pthread_cached = NULL;

/// Attempt to cache main thread info if the current thread is the main thread.
/// Returns true if main thread info is available (either just resolved or previously cached).
///
/// Thread-safety: safe to call from the constructor (single-threaded) and from
/// emb_sampler_start (CAS-gated STARTING state, so at most one caller).
static bool resolve_main_thread_if_current(void) {
    if (g_main_mach_thread_cached != MACH_PORT_NULL) {
        return true;
    }
    if (!pthread_main_np()) {
        return false;
    }
    g_main_pthread_cached = pthread_self();
    g_main_mach_thread_cached = pthread_mach_thread_np(g_main_pthread_cached);
    return g_main_mach_thread_cached != MACH_PORT_NULL;
}

__attribute__((constructor))
static void emb_sampler_init(void) {
    g_profiling_log = os_log_create("com.embrace.profiling", "sampler");
    // Best-effort: cache main thread info if the constructor runs on main (the
    // common case for statically linked SPM targets). If it runs on a non-main
    // thread (e.g. dlopen from a background thread), we defer resolution to the
    // first emb_sampler_start() call made from the main thread.
    resolve_main_thread_if_current();
}

static inline emb_sampler_state_t sampler_get_state(void) {
    return (emb_sampler_state_t)atomic_load_explicit(&g_state, memory_order_acquire);
}

/// Returns CAS_SUCCESS (0) on success, or the actual state on failure.
/// Enum values are all non-zero (power-of-2), so 0 is unambiguous.
static inline int sampler_cas_state(emb_sampler_state_t expected, emb_sampler_state_t desired) {
    int e = expected;
    if (atomic_compare_exchange_strong_explicit(&g_state, &e, desired,
                                                memory_order_release,
                                                memory_order_relaxed)) {
        return CAS_SUCCESS;
    }
    return e;
}

/// Tries to CAS from each state in valid_from_mask to desired.
/// Invariant: valid_from_mask has at least one set bit.
/// Returns CAS_SUCCESS (0) on first successful CAS.
/// Returns actual state if no CAS succeeds (i.e. actual state is not in the mask).
static inline int sampler_cas_multi(int valid_from_mask, emb_sampler_state_t desired) {
    int actual = CAS_SUCCESS;
    int remaining = valid_from_mask;
    while (remaining) {
        int bit = remaining & (-remaining);  // isolate lowest set bit
        actual = sampler_cas_state((emb_sampler_state_t)bit, desired);
        if (actual == CAS_SUCCESS) {
            break;
        }
        remaining &= ~bit;
    }
    return actual;
}


/// Unconditional store to FAULTED. Terminal emergency, no precondition needed.
/// The reason must be a non-NULL string literal (or static-lifetime buffer).
/// Do not pass NULL; a fallback string will be used but this indicates a bug
/// in the caller.
///
/// INTENTIONAL LEAK PHILOSOPHY:
/// When we fault, the worker thread and g_stack_frames are abandoned. We do
/// not join the thread or free the buffer because:
///   1. The fault conditions (dead Mach port, state violation) mean the runtime
///      is broken; attempting cleanup risks further undefined behavior.
///   2. The worker thread may be stuck (e.g. target thread left suspended with
///      a dead port), so pthread_join could block indefinitely.
///   3. Leaking a few KB is preferable to risking deadlock or use-after-free.
///
/// MEMORY ORDERING CONTRACT:
/// The non-atomic write to g_fault_reason happens-before the release-store to
/// g_state. Readers who observe FAULTED via acquire-load (sampler_get_state)
/// are guaranteed to see the correct reason string.
static inline void sampler_fault(const char *reason) {
    g_fault_reason = reason ? reason : "no reason given";
    atomic_store_explicit(&g_state, EMB_SAMPLER_FAULTED, memory_order_release);
}


/// Validated state transition. Tries CAS from each state in valid_from_mask to desired.
/// Invariant: valid_from_mask has at least one set bit.
/// Returns true on first successful CAS.
/// If no CAS succeeds, (i.e. actual state is not in the mask), logs error, faults, and returns false.
static inline bool sampler_checked_transition(int valid_from_mask, emb_sampler_state_t desired) {
    int actual = sampler_cas_multi(valid_from_mask, desired);
    if (actual == CAS_SUCCESS) {
        return true;
    }
    os_log_error(emb_profiling_log(),
                 "State violation: expected mask 0x%x, actual 0x%x", valid_from_mask, actual);
    sampler_fault("state machine violation");
    return false;
}

static inline uint64_t clamp_u64(uint64_t val, uint64_t min, uint64_t max) {
    if (val < min) return min;
    if (val > max) return max;
    return val;
}

static void *sampler_thread_func(void *arg) {
    (void)arg;

    // Verify we're in the expected state and transition to RUNNING.
    // If stop() was called during startup, state is STOPPING, so skip
    // straight to ZOMBIE. Any other state is a bug, so we fault.
    if (sampler_cas_state(EMB_SAMPLER_STARTING, EMB_SAMPLER_RUNNING) != CAS_SUCCESS) {
        sampler_checked_transition(EMB_SAMPLER_STOPPING, EMB_SAMPLER_ZOMBIE);
        return NULL;
    }

    // USER_INITIATED: one tier below the main thread's USER_INTERACTIVE.
    // The sampler holds the main thread suspended during the stack walk
    // (~microseconds), so it must complete promptly to minimize stall.
    // USER_INITIATED prevents priority inversion from utility/background
    // work without competing with the main thread itself. The QoS is
    // irrelevant during the 100ms sleep between samples.
    (void)pthread_set_qos_class_self_np(QOS_CLASS_USER_INITIATED, 0);

    const emb_fallback_stack_walker_fn fallback_walker = g_config.fallback_walker;

    uint64_t next_deadline = mach_absolute_time();

    while (sampler_get_state() == EMB_SAMPLER_RUNNING) {
        // Re-read stack bounds each cycle. pthread_get_stackaddr_np/stacksize_np
        // are safe to call from any thread and read directly from the pthread
        // struct. Done before thread_suspend so we're outside the async-safe section.
        size_t stack_size = pthread_get_stacksize_np(g_main_pthread_cached);
        void *stack_top = pthread_get_stackaddr_np(g_main_pthread_cached);
        void *stack_bottom = (uint8_t *)stack_top - stack_size;

        if (thread_suspend(g_main_thread) != KERN_SUCCESS) {
            // The Mach port is dead/invalid (thread terminated or port recycled).
            // We go directly to FAULTED, bypassing the normal STOPPING→ZOMBIE→
            // REAPING→STOPPED path. The worker thread returns without being joined,
            // and g_stack_frames is leaked. See sampler_fault() for rationale.
            os_log_debug(emb_profiling_log(), "Worker thread exiting: thread_suspend failed");
            sampler_fault("thread_suspend failed (target thread terminated or port invalid)");
            return NULL;
        }

        // ====================================================================
        // BEGIN ASYNC-SAFE SECTION
        // - Do NOT call sampler_checked_transition
        // - Do NOT emit logs
        // - Do NOT allocate
        // - Do NOT lock

        uint64_t timestamp_ns = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);

        size_t frame_count = 0;
        emb_stack_walk(g_main_thread,
                       stack_bottom,
                       stack_top,
                       g_stack_frames,
                       g_config.max_frames,
                       &frame_count);

        if (frame_count < g_config.min_frames && fallback_walker != NULL) {
            bool is_truncated = false;
            int result = fallback_walker(g_main_thread,
                                         g_stack_frames,
                                         (int)g_config.max_frames,
                                         &is_truncated);
            frame_count = result < 0 ? 0 : (size_t)result;
        }

        if (thread_resume(g_main_thread) != KERN_SUCCESS) {
            // The Mach port is dead/invalid. The target thread is left
            // suspended (if it still exists) because we have no valid port
            // to resume it, and retrying would fail identically. Same fault
            // path as thread_suspend: direct to FAULTED, worker thread and
            // g_stack_frames are leaked. See sampler_fault() for rationale.
            sampler_fault("thread_resume failed (target thread terminated or port invalid)");
            return NULL;
        }

        // END ASYNC-SAFE SECTION
        // ====================================================================

        // Write the captured stack trace to the ring buffer.
        // In normal operation this always succeeds because emb_sampler_start
        // validates that max_frames fits within the buffer capacity. A failure
        // here indicates a logic error (e.g. buffer was destroyed externally).
        if (frame_count > 0) {
            if (!emb_ring_buffer_write(g_buffer, timestamp_ns, g_stack_frames, frame_count)) {
                sampler_fault("ring buffer write failed (buffer corrupt or misconfigured)");
                return NULL;
            }
        }

        if (sampler_get_state() != EMB_SAMPLER_RUNNING) {
            break;
        }

        next_deadline += g_interval_ticks;

        // Clamp the sleep to [min, max] interval from now. If the deadline
        // is too low (e.g. from a slow fallback walker), we'd end up doing
        // back-to-back samples, starving the main thread of runtime. If too
        // high, we could effectively lock up this worker thread.
        uint64_t now = mach_absolute_time();
        next_deadline = clamp_u64(next_deadline, now + g_min_interval_ticks, now + g_max_interval_ticks);

        mach_wait_until(next_deadline);
    }

    sampler_checked_transition(EMB_SAMPLER_STOPPING, EMB_SAMPLER_ZOMBIE);
    return NULL;
}

/// Clean up resources from a finished previous session.
///
/// CAS-gated: only one caller wins the ZOMBIE -> REAPING transition.
/// Losers (and callers in any other state) return immediately.
static void cleanup_previous_session(void) {
    if (sampler_cas_state(EMB_SAMPLER_ZOMBIE, EMB_SAMPLER_REAPING) != CAS_SUCCESS) {
        return;
    }

    pthread_join(g_worker, NULL);
    free(g_stack_frames);
    g_stack_frames = NULL;
    g_buffer = NULL;
    sampler_checked_transition(EMB_SAMPLER_REAPING, EMB_SAMPLER_STOPPED);
}

emb_sampler_start_result_t emb_sampler_start(emb_ring_buffer_t *buffer, emb_sampler_config_t config) {
    // Reap any finished previous session.
    cleanup_previous_session();

    // Gate: CAS STOPPED -> STARTING. Only one caller can win.
    int state = sampler_cas_state(EMB_SAMPLER_STOPPED, EMB_SAMPLER_STARTING);
    switch (state) {
        case CAS_SUCCESS:          // We won the CAS race to STARTING.
            break;
        case EMB_SAMPLER_RUNNING:  // Already running; check if config+buffer match.
            if (buffer == g_buffer &&
                memcmp(&config, &g_config, sizeof(config)) == 0) {
                return EMB_SAMPLER_START_OK;
            }
            return EMB_SAMPLER_START_CONFIG_MISMATCH;
        case EMB_SAMPLER_FAULTED:  // We're permanently broken.
            return EMB_SAMPLER_START_ERROR;
        case EMB_SAMPLER_STARTING: // Someone else is starting.
        case EMB_SAMPLER_STOPPING: // We haven't finished stopping yet.
        case EMB_SAMPLER_ZOMBIE:   // We haven't finished stopping yet.
        case EMB_SAMPLER_REAPING:  // We haven't finished stopping yet.
            return EMB_SAMPLER_START_BUSY;
        default:
            // BUG: We forgot to handle a new state that was added.
            os_log_debug(emb_profiling_log(), "emb_sampler_start failed: unhandled state %d", state);
            sampler_fault("unhandled state in emb_sampler_start");
            return EMB_SAMPLER_START_ERROR;
    }

    // We own the STARTING state. Validate config.

    if (buffer == NULL) {
        os_log_debug(emb_profiling_log(), "emb_sampler_start failed: null buffer");
        sampler_checked_transition(EMB_SAMPLER_STARTING_OR_STOPPING_MASK, EMB_SAMPLER_STOPPED);
        return EMB_SAMPLER_START_ERROR;
    }
    if (config.sampling_interval_ms == 0 || config.min_sampling_interval_ms == 0 ||
        config.max_frames == 0 || config.min_sampling_interval_ms > config.sampling_interval_ms) {
        os_log_debug(emb_profiling_log(), "emb_sampler_start failed: invalid config");
        sampler_checked_transition(EMB_SAMPLER_STARTING_OR_STOPPING_MASK, EMB_SAMPLER_STOPPED);
        return EMB_SAMPLER_START_ERROR;
    }

    if (config.max_frames > EMB_MAX_STACK_FRAMES) {
        os_log_debug(emb_profiling_log(),
                     "Clamping max_frames from %u to %d", config.max_frames, EMB_MAX_STACK_FRAMES);
        config.max_frames = EMB_MAX_STACK_FRAMES;
    }

    // Resolve main thread info. The constructor caches it when loaded on main;
    // if that missed (e.g. dlopen from a background thread), try again now.
    if (!resolve_main_thread_if_current()) {
        os_log_debug(emb_profiling_log(),
                     "emb_sampler_start failed: main thread info unavailable"
                     " (call start() from the main thread at least once)");
        sampler_checked_transition(EMB_SAMPLER_STARTING_OR_STOPPING_MASK, EMB_SAMPLER_STOPPED);
        return EMB_SAMPLER_START_ERROR;
    }

    g_stack_frames = malloc((size_t)config.max_frames * sizeof(*g_stack_frames));
    if (g_stack_frames == NULL) {
        sampler_checked_transition(EMB_SAMPLER_STARTING_OR_STOPPING_MASK, EMB_SAMPLER_STOPPED);
        return EMB_SAMPLER_START_ERROR;
    }

    // Compute intervals in mach absolute time ticks.
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    g_interval_ticks =
        ((uint64_t)config.sampling_interval_ms * NS_PER_MS * timebase.denom)
        / timebase.numer;
    g_min_interval_ticks =
        ((uint64_t)config.min_sampling_interval_ms * NS_PER_MS * timebase.denom)
        / timebase.numer;
    // Upper bound: 2x target interval. Purely a safeguard against a bad
    // deadline miscalculation producing a huge sleep.
    g_max_interval_ticks = 2 * g_interval_ticks;

    g_buffer = buffer;
    g_config = config;
    g_main_thread = g_main_mach_thread_cached;

    // Worker thread will handle the transition to RUNNING.
    if (pthread_create(&g_worker, NULL, sampler_thread_func, NULL) != 0) {
        os_log_debug(emb_profiling_log(), "emb_sampler_start failed: thread creation failure");
        free(g_stack_frames);
        g_stack_frames = NULL;
        sampler_checked_transition(EMB_SAMPLER_STARTING_OR_STOPPING_MASK, EMB_SAMPLER_STOPPED);
        return EMB_SAMPLER_START_ERROR;
    }

    return EMB_SAMPLER_START_OK;
}

void emb_sampler_stop(void) {
    sampler_cas_multi(EMB_SAMPLER_RUNNING | EMB_SAMPLER_STARTING,  EMB_SAMPLER_STOPPING);
}

bool emb_sampler_is_active(void) {
    switch (sampler_get_state()) {
        case EMB_SAMPLER_ZOMBIE:
            cleanup_previous_session();
            return false;
        case EMB_SAMPLER_STARTING:
        case EMB_SAMPLER_RUNNING:
        case EMB_SAMPLER_STOPPING:
            return true;
        default:
            return false;
    }
}

emb_sampler_state_t emb_sampler_get_state(void) {
    return sampler_get_state();
}

const char *emb_sampler_get_fault_reason(void) {
    if (sampler_get_state() != EMB_SAMPLER_FAULTED) {
        return NULL;
    }
    return g_fault_reason;
}

// ---------------------------------------------------------------------------
// TEST-ONLY APIs
// ---------------------------------------------------------------------------

bool emb_sampler_reset_for_testing(void) {
    emb_sampler_state_t state = sampler_get_state();
    if (state != EMB_SAMPLER_STOPPED && state != EMB_SAMPLER_FAULTED) {
        return false;
    }
    g_fault_reason = NULL;
    atomic_store_explicit(&g_state, EMB_SAMPLER_STOPPED, memory_order_release);
    return true;
}

// Static buffer for injected fault reasons. Callers from Swift pass
// temporaries (automatic String-to-const char* bridging), so we must
// copy the string to storage with process lifetime.
static char g_injected_fault_reason[256];

void emb_sampler_inject_fault_for_testing(const char *reason) {
    // NOTE: The strlcpy to the static buffer is not thread-safe vs concurrent
    // reads of g_fault_reason. This is acceptable because inject_fault is
    // test-only code that runs in serialized setUp/tearDown contexts.
    if (reason) {
        strlcpy(g_injected_fault_reason, reason, sizeof(g_injected_fault_reason));
        sampler_fault(g_injected_fault_reason);
    } else {
        sampler_fault(NULL);
    }
}

void emb_sampler_set_main_thread_for_testing(thread_t mach_thread, pthread_t pthread) {
    g_main_mach_thread_cached = mach_thread;
    g_main_pthread_cached = pthread;
}

#endif /* !TARGET_OS_WATCH */
