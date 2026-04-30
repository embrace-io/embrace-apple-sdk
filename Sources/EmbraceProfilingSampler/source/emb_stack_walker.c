//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#include "emb_stack_walker.h"

#if !TARGET_OS_WATCH

#include <mach/mach.h>
#include <ptrauth.h>

// Architecture-specific thread state access.
#if defined(__arm64__) || defined(__aarch64__)
  #define EMB_THREAD_STATE_FLAVOR  ARM_THREAD_STATE64
  #define EMB_THREAD_STATE_COUNT   ARM_THREAD_STATE64_COUNT
  typedef arm_thread_state64_t     emb_thread_state_t;
  #define EMB_GET_PC(s) ((void *)arm_thread_state64_get_pc(s))
  #define EMB_GET_FP(s) ((void *)arm_thread_state64_get_fp(s))
#elif defined(__x86_64__)
  #define EMB_THREAD_STATE_FLAVOR  x86_THREAD_STATE64
  #define EMB_THREAD_STATE_COUNT   x86_THREAD_STATE64_COUNT
  typedef x86_thread_state64_t     emb_thread_state_t;
  #define EMB_GET_PC(s) ((void *)(s).__rip)
  #define EMB_GET_FP(s) ((void *)(s).__rbp)
#endif

bool emb_stack_walk(thread_t thread,
                    const void *stack_bottom,
                    const void *stack_top,
                    uintptr_t *frames_out,
                    size_t max_frames,
                    size_t *count_out)
{
    if (frames_out == NULL || count_out == NULL || max_frames == 0
        || stack_bottom == NULL || stack_top == NULL
        || stack_bottom >= stack_top) {
        return false;
    }
    *count_out = 0;

    emb_thread_state_t state;
    mach_msg_type_number_t state_count = EMB_THREAD_STATE_COUNT;
    kern_return_t kr = thread_get_state(thread,
                                        EMB_THREAD_STATE_FLAVOR,
                                        (thread_state_t)&state,
                                        &state_count);
    if (kr != KERN_SUCCESS) {
        return false;
    }

    void *pc = EMB_GET_PC(state);
    void *fp = EMB_GET_FP(state);
    size_t count = 0;

    if (pc != NULL) {
        frames_out[count++] = (uintptr_t)pc;
    }

    // Walk the frame pointer chain.
    // Each frame record is: [saved_fp, return_address]
    // Frame pointers must be aligned to sizeof(void *) * 2 bytes
    // (16 bytes on the supported 64-bit architectures).
    const uintptr_t fp_align_mask = sizeof(void *) * 2 - 1;
    while (count < max_frames && fp >= stack_bottom && fp < stack_top
           && ((uintptr_t)fp & fp_align_mask) == 0) {
        void **record = (void **)fp;
        void *next_fp = record[0];
        void *ret_addr = ptrauth_strip(record[1], ptrauth_key_return_address);

        if (ret_addr == NULL) {
            break;
        }

        frames_out[count++] = (uintptr_t)ret_addr;

        if (next_fp == NULL || (uintptr_t)next_fp <= (uintptr_t)fp) {
            break;
        }
        fp = next_fp;
    }

    *count_out = count;
    return true;
}

#endif /* !TARGET_OS_WATCH */
