//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#ifndef emb_test_thread_nofp_h
#define emb_test_thread_nofp_h

#include <TargetConditionals.h>

#if !TARGET_OS_WATCH

#include <mach/mach_types.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Opaque handle to a test thread compiled without frame pointers.
typedef struct emb_test_thread_nofp *emb_test_thread_nofp_t;

/// Create a thread that recurses to the given stack depth then spins.
/// This target is compiled with -fomit-frame-pointer.
/// On arm64 the flag is ignored (ABI mandates FPs); on x86_64 it takes effect.
/// Returns NULL on failure.
emb_test_thread_nofp_t emb_test_thread_nofp_create(size_t stack_depth);

/// Returns the Mach thread port for the test thread.
thread_t emb_test_thread_nofp_get_port(emb_test_thread_nofp_t t);

/// Signal the thread to stop and wait for it to exit, then free resources.
void emb_test_thread_nofp_destroy(emb_test_thread_nofp_t t);

#ifdef __cplusplus
}
#endif

#endif /* !TARGET_OS_WATCH */

#endif /* emb_test_thread_nofp_h */
