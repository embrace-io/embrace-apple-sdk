//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#include "emb_stack_walker.h"

#if !TARGET_OS_WATCH

int emb_stack_walk(thread_t thread,
                   uint64_t *frames_out,
                   uint32_t max_frames,
                   uint32_t *count_out)
{
    (void)thread;
    (void)frames_out;
    (void)max_frames;
    (void)count_out;
    return -1;
}

#endif /* !TARGET_OS_WATCH */
