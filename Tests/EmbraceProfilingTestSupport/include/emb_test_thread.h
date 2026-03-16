//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#ifndef emb_test_thread_h
#define emb_test_thread_h

#include <TargetConditionals.h>

#if !TARGET_OS_WATCH

#include <mach/mach_types.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Opaque handle to a test thread.
typedef struct emb_test_thread *emb_test_thread_t;

/// Create a thread that recurses to the given stack depth then spins.
/// The thread is running (not suspended) on return.
/// Returns NULL on failure.
emb_test_thread_t emb_test_thread_create(size_t stack_depth);

/// Returns the Mach thread port for the test thread.
thread_t emb_test_thread_get_port(emb_test_thread_t t);

/// Signal the thread to stop and wait for it to exit, then free resources.
void emb_test_thread_destroy(emb_test_thread_t t);

#ifdef __cplusplus
}
#endif

#endif /* !TARGET_OS_WATCH */

#endif /* emb_test_thread_h */
