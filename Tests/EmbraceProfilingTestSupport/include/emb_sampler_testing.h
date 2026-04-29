//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#ifndef emb_sampler_testing_h
#define emb_sampler_testing_h

#include <TargetConditionals.h>

#if !TARGET_OS_WATCH

#include <mach/mach_types.h>
#include <pthread.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// ---------------------------------------------------------------------------
// TEST-ONLY APIs
//
// These functions are defined in EmbraceProfilingSampler (emb_sampler.c).
// They exist solely for unit testing. Do NOT call them from production code.
// ---------------------------------------------------------------------------

/// TEST-ONLY: Reset sampler from STOPPED or FAULTED back to clean STOPPED state.
/// Clears fault reason. Returns false if sampler is active (STARTING/RUNNING/STOPPING/etc).
bool emb_sampler_reset_for_testing(void);

/// TEST-ONLY: Force the sampler into FAULTED state with the given reason.
/// The reason is copied internally, so it does not need static storage duration.
/// Pass NULL to use the default fault reason.
void emb_sampler_inject_fault_for_testing(const char *reason);

/// TEST-ONLY: Override the cached main thread ports.
/// Allows the sampler to target a test thread instead of the real main thread.
/// Pass MACH_PORT_NULL / NULL to clear the cache (next start() will re-resolve).
void emb_sampler_set_main_thread_for_testing(thread_t mach_thread, pthread_t pthread);

#ifdef __cplusplus
}
#endif

#endif /* !TARGET_OS_WATCH */

#endif /* emb_sampler_testing_h */
