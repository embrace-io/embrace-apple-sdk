//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

// This file is intentionally compiled with -fomit-frame-pointer (set in
// Package.swift cSettings for this target). On arm64 the flag is a no-op
// because the ABI mandates frame pointers; on x86_64 it strips them.

#include "emb_test_thread_nofp.h"

#if !TARGET_OS_WATCH

#include <pthread.h>
#include <stdlib.h>
#include <unistd.h>
#include <mach/mach.h>

struct emb_test_thread_nofp {
    pthread_t pthread;
    thread_t mach_port;
    volatile int running;
    size_t stack_depth;
};

__attribute__((noinline))
static void recurse_nofp(volatile int *flag, size_t depth) {
    volatile size_t anchor = depth;
    if (depth > 0) {
        recurse_nofp(flag, depth - 1);
    } else {
        while (*flag) { }
    }
    (void)anchor;
}

static void *thread_entry_nofp(void *arg) {
    struct emb_test_thread_nofp *t = (struct emb_test_thread_nofp *)arg;
    recurse_nofp(&t->running, t->stack_depth);
    return NULL;
}

emb_test_thread_nofp_t emb_test_thread_nofp_create(size_t stack_depth) {
    struct emb_test_thread_nofp *t = calloc(1, sizeof(*t));
    if (t == NULL) {
        return NULL;
    }

    t->running = 1;
    t->stack_depth = stack_depth;

    if (pthread_create(&t->pthread, NULL, thread_entry_nofp, t) != 0) {
        free(t);
        return NULL;
    }

    // Let the thread settle into its spin loop.
    usleep(50000);
    t->mach_port = pthread_mach_thread_np(t->pthread);

    return t;
}

thread_t emb_test_thread_nofp_get_port(emb_test_thread_nofp_t t) {
    return t->mach_port;
}

void emb_test_thread_nofp_destroy(emb_test_thread_nofp_t t) {
    t->running = 0;
    pthread_join(t->pthread, NULL);
    free(t);
}

#endif /* !TARGET_OS_WATCH */
