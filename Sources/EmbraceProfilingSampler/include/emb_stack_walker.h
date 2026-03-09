//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#ifndef emb_stack_walker_h
#define emb_stack_walker_h

#include <TargetConditionals.h>

#if !TARGET_OS_WATCH

#include <mach/mach_types.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Walk the frame pointer chain of the given thread, storing return addresses
/// into `frames_out`. At most `max_frames` will be captured. The actual count
/// is written to `count_out`.
///
/// Returns 0 on success, -1 on failure.
int emb_stack_walk(thread_t thread,
                   uint64_t *frames_out,
                   uint32_t max_frames,
                   uint32_t *count_out);

#ifdef __cplusplus
}
#endif

#endif /* !TARGET_OS_WATCH */

#endif /* emb_stack_walker_h */
