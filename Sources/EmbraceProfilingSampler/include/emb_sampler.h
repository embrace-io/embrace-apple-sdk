//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

/// Lock-free profiling sampler that periodically captures stack traces of the
/// main thread.
///
/// Principles of operation:
///
/// A dedicated worker thread runs a timer loop that, on each tick, suspends
/// the main thread via its Mach port, walks the stack to capture frame
/// addresses, then immediately resumes the main thread. The suspension
/// window is kept to microseconds, just long enough for the stack walk.
///
/// The critical constraint is that the main thread may hold *any* lock when
/// it is suspended (malloc, objc runtime, os_log, etc.). Everything the
/// worker does while the main thread is suspended must therefore be
/// async-signal-safe: no allocation, no locks, no syscalls that can block.
/// This rules out most of libc, and all of Objective-C and Swift.
///
/// Stack walking uses a fast frame-pointer chain walker (emb_stack_walker)
/// that reads thread register state via the Mach thread_get_state trap and
/// then follows FP -> LR pairs within validated stack bounds. If the primary
/// walker produces fewer frames than a configurable minimum (e.g. leaf
/// functions compiled without frame pointers), an optional fallback walker
/// callback is invoked while the thread is still suspended. The fallback
/// must also be async-safe.
///
/// Captured samples (timestamp + frame addresses) are appended to a
/// caller-owned ring buffer (emb_ring_buffer). The ring buffer is
/// single-writer / multiple-reader and uses a seqlock for torn-read
/// detection, so the writer (this sampler) never blocks. Readers on other
/// threads can query by time range without interfering with sampling.
///
/// Lifecycle is governed by an atomic state machine (see emb_sampler_state_t
/// below). All transitions use CAS to guarantee single-owner semantics:
/// only one thread can start, and only one thread can reap. The stop path
/// is non-blocking: it flips a flag and the worker exits on its next
/// iteration. Unrecoverable errors (dead Mach port, state violation)
/// transition to a terminal FAULTED state, intentionally leaking the worker
/// thread and frame buffer rather than risking deadlock or use-after-free
/// during cleanup.

#ifndef emb_sampler_h
#define emb_sampler_h

#include <TargetConditionals.h>

#if !TARGET_OS_WATCH

#include <mach/mach_types.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>

#include "emb_ring_buffer.h"

#ifdef __cplusplus
extern "C" {
#endif

/// Hard upper limit on stack frames per sample.
#define EMB_MAX_STACK_FRAMES 1024

/// Sampler lifecycle states.
///
/// Transitions:
///   STOPPED  -> STARTING  (start called. CAS-gated, single winner)
///   STARTING -> RUNNING   (worker thread begins sampling)
///   STARTING -> STOPPING  (stop requested before worker began)
///   STARTING -> STOPPED   (setup failed. reverted)
///   RUNNING  -> STOPPING  (stop requested)
///   STOPPING -> ZOMBIE    (worker exits)
///   ZOMBIE   -> REAPING   (cleanup begins. CAS-gated, single winner)
///   REAPING  -> STOPPED   (cleanup complete)
///   RUNNING  -> FAULTED   (thread_suspend/resume failure. terminal)
///   STOPPING -> FAULTED   (thread_suspend/resume failure. terminal)
/// Bit assignments are ordered so that the most common CAS target in
/// multi-state masks has the lowest bit, allowing `sampler_cas_multi`
/// (which iterates LSB-first) to succeed on the first attempt in the
/// typical case. Specifically, RUNNING is less than STARTING because
/// `emb_sampler_stop` CAS-es from {RUNNING, STARTING} and the sampler
/// is almost always RUNNING when stop is called.
typedef enum {
    EMB_SAMPLER_STOPPED  = 1 << 0,  // No worker, no resources (initial + post-stop).
    EMB_SAMPLER_RUNNING  = 1 << 1,  // Worker active, sampling.
    EMB_SAMPLER_STARTING = 1 << 2,  // Setup in progress (CAS-gated, single owner).
    EMB_SAMPLER_STOPPING = 1 << 3,  // Stop requested, worker still alive.
    EMB_SAMPLER_ZOMBIE   = 1 << 4,  // Worker exited, needs join + cleanup.
    EMB_SAMPLER_REAPING  = 1 << 5,  // Cleanup in progress (join + free).
    EMB_SAMPLER_FAULTED  = 1 << 6,  // Unrecoverable runtime error, permanently dead.
                                    // Intentionally terminal: the worker thread and
                                    // g_stack_frames are leaked (not joined/freed).
                                    // Recovery is impossible in production because the
                                    // fault conditions (dead Mach port, state machine
                                    // violation) indicate a broken runtime. The only
                                    // path back to STOPPED is reset_for_testing, which
                                    // accepts the leaks for test isolation.
} emb_sampler_state_t;

/// Fallback stack walker callback.
///
/// Called when the primary frame-pointer walker yields fewer than
/// `min_frames`. The target thread is already suspended when invoked.
///
/// Must be async-signal-safe: no allocation, no locks, no libc calls that
/// can block. The sampler holds the target thread suspended across this
/// call, so any blocking or allocating work here risks deadlock (e.g. if
/// the suspended thread holds the malloc lock).
///
/// Designed to match the signature of ksbt_captureBacktraceFromSuspendedMachThread
/// (see kstenerud/KSCrash#816).
///
/// @param thread        Mach thread port (already suspended).
/// @param frames_out    Output buffer for frame addresses.
/// @param max_frames    Capacity of frames_out.
/// @param is_truncated  Set to true if the stack exceeded max_frames.
/// @return The number of frames captured, or 0 on failure. Must be positive.
typedef int (*emb_fallback_stack_walker_fn)(thread_t thread,
                                            uintptr_t *frames_out,
                                            int max_frames,
                                            bool *is_truncated);

/// Configuration for the profiling sampler.
///
/// The sampler aims to sample at `sampling_interval_ms`. If a sample
/// overruns (e.g. a slow fallback walker), subsequent sleeps are shortened
/// to catch up, but never below `min_sampling_interval_ms`. The min floor
/// exists to prevent pathological cases where drift recovery degenerates
/// into back-to-back sampling, starving the main thread of runtime.
typedef struct {
    uint32_t sampling_interval_ms;                // Target interval between samples (ms). Must be > 0.
    uint32_t min_sampling_interval_ms;            // Minimum interval when recovering from drift (ms).
                                                  // Must be > 0 and <= sampling_interval_ms.
    uint32_t max_frames;                          // Maximum frames per sample. Must be > 0.
    uint32_t min_frames;                          // Minimum frames before fallback to alternate stack walk (0 = no fallback).
    emb_fallback_stack_walker_fn fallback_walker; // Fallback stack walker (NULL = no fallback).
} emb_sampler_config_t;

/// Result of an emb_sampler_start() call.
typedef enum {
    EMB_SAMPLER_START_OK,              // Sampler successfully started, or already running with same config+buffer.
    EMB_SAMPLER_START_BUSY,            // A previous session is still stopping/being reaped. Retry later.
    EMB_SAMPLER_START_CONFIG_MISMATCH, // Already running with a different config or buffer.
    EMB_SAMPLER_START_ERROR,           // Permanent failure (invalid config, null buffer, faulted, etc).
} emb_sampler_start_result_t;

/// Start sampling the main thread into the given ring buffer.
///
/// May be called from any thread. Main thread info is captured at load
/// time via a constructor. If main thread is unavailable, returns ERROR.
///
/// The buffer is NOT owned by the sampler. The caller must ensure it
/// outlives the sampler (i.e. do not destroy the buffer while
/// emb_sampler_is_active() returns true).
///
/// Idempotent for the same config+buffer: if the sampler is already
/// running with identical arguments, returns OK without changing anything.
///
/// If a previous session is still shutting down or being reaped, returns
/// BUSY without blocking. Callers should retry later.
///
/// If the sampler is already running with a different config or buffer,
/// returns CONFIG_MISMATCH. Callers should stop the current session first.
///
/// Returns ERROR on invalid config, null buffer, thread creation failure,
/// or if the sampler is in a permanently faulted state.
emb_sampler_start_result_t emb_sampler_start(emb_ring_buffer_t *buffer, emb_sampler_config_t config);

/// Request the sampler to stop.
///
/// This is non-blocking and fire-and-forget: it signals the worker thread
/// to exit and returns immediately with no feedback. The worker thread
/// will stop on its next iteration (within one sampling interval). Poll
/// emb_sampler_is_active() to determine when the worker has actually exited.
///
/// Idempotent: safe to call when already stopped or already stopping.
/// No-op if the sampler is not in RUNNING or STARTING state.
void emb_sampler_stop(void);

/// Returns true if the sampler is active (STARTING, RUNNING, or STOPPING).
///
/// While active, the resources being used by the sampler MUST NOT be freed!
///
/// Returns false if the sampler was never started, has finished stopping,
/// is in a faulted state, or was never able to start.
///
/// If the worker has exited (ZOMBIE state), this function joins the thread
/// and cleans up resources before returning false, so polling until false
/// guarantees a fully clean state.
bool emb_sampler_is_active(void);

/// Get the current state of the sampler.
///
/// Note: EMB_SAMPLER_RUNNING means the worker is actively capturing stack
/// traces. This is distinct from emb_sampler_is_active() which returns true
/// for any non-idle state (STARTING, RUNNING, STOPPING).
emb_sampler_state_t emb_sampler_get_state(void);

/// Get the fault reason string, or NULL if the sampler is not faulted.
///
/// The returned pointer is valid for the lifetime of the process (static storage).
/// Do not free it.
const char *emb_sampler_get_fault_reason(void);

#ifdef __cplusplus
}
#endif

#endif /* !TARGET_OS_WATCH */

#endif /* emb_sampler_h */
