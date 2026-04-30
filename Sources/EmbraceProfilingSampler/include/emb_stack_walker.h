//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

/// Async-safe frame-pointer stack walker for suspended Mach threads.
///
/// Principles of operation:
///
/// - Calls thread_get_state (a Mach trap) to read the target thread's PC
///   and frame pointer (FP). The PC becomes the first captured frame.
/// - Walks the FP chain: each stack frame is a [saved_FP, return_address]
///   pair. The return address is captured (after stripping ARM64 PAC via
///   ptrauth_strip), then the walker advances to the saved FP.
/// - Stops when: max_frames reached, FP leaves the provided stack bounds,
///   FP is misaligned, return address is NULL, or FP stops ascending
///   (cycle guard).
///
/// Async-safety:
///
/// - The only kernel interaction is thread_get_state (a Mach trap, never
///   blocks). Everything else is pointer arithmetic within caller-provided
///   stack bounds.
/// - This is essential because the target thread is suspended and may hold
///   any userspace lock; the walker must never attempt to acquire one.
/// - Callers must resolve stack bounds (pthread_get_stackaddr_np /
///   pthread_get_stacksize_np) *before* suspending the thread, since those
///   pthread APIs are not async-safe.

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
/// Async-safe: only calls `thread_get_state` (a Mach trap) and walks memory
/// within the provided stack bounds. Callers must resolve stack bounds before
/// the target thread is suspended (pthread APIs are not async-safe).
///
/// @param thread       Mach thread port (must be suspended).
/// @param stack_bottom Lowest valid stack address.
/// @param stack_top    Highest valid stack address (pthread_get_stackaddr_np).
/// @param frames_out   Output buffer for frame addresses.
/// @param max_frames   Capacity of frames_out.
/// @param count_out    On return, the number of frames captured.
/// @return true on success, false on failure.
bool emb_stack_walk(thread_t thread,
                    const void *stack_bottom,
                    const void *stack_top,
                    uintptr_t *frames_out,
                    size_t max_frames,
                    size_t *count_out);

#ifdef __cplusplus
}
#endif

#endif /* !TARGET_OS_WATCH */

#endif /* emb_stack_walker_h */
