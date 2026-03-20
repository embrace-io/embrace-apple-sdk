//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#ifndef emb_stack_walker_h
#define emb_stack_walker_h

#include <TargetConditionals.h>

#if !TARGET_OS_WATCH

#include <mach/mach_types.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Walk the frame pointer chain of the given thread, storing return addresses
/// into `frames_out`. At most `max_frames` will be captured. The actual count
/// is written to `count_out`.
///
/// Returns true on success, false on failure.
bool emb_stack_walk(thread_t thread,
                    uintptr_t *frames_out,
                    size_t max_frames,
                    size_t *count_out);

#ifdef __cplusplus
}
#endif

#endif /* !TARGET_OS_WATCH */

#endif /* emb_stack_walker_h */
