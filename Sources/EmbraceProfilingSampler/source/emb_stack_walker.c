//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#include "emb_stack_walker.h"

#if !TARGET_OS_WATCH

#include <mach/mach.h>
#include <pthread.h>
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
                    uintptr_t *frames_out,
                    size_t max_frames,
                    size_t *count_out)
{
    if (frames_out == NULL || count_out == NULL || max_frames == 0) {
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

    // Determine the target thread's stack bounds for safe direct dereference.
    pthread_t target_pthread = pthread_from_mach_thread_np(thread);
    if (target_pthread == NULL) {
        return false;
    }
    void *stack_top = pthread_get_stackaddr_np(target_pthread);
    size_t stack_size = pthread_get_stacksize_np(target_pthread);
    void *stack_bottom = (char *)stack_top - stack_size;

    void *pc = EMB_GET_PC(state);
    void *fp = EMB_GET_FP(state);
    size_t count = 0;

    if (pc != NULL) {
        frames_out[count++] = (uintptr_t)pc;
    }

    // Walk the frame pointer chain.
    // Each frame record is: [saved_fp, return_address]
    while (count < max_frames && fp >= stack_bottom && fp < stack_top) {
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
