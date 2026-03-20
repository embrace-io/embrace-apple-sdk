//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#include "emb_test_thread.h"

#if !TARGET_OS_WATCH

#include <pthread.h>
#include <stdlib.h>
#include <unistd.h>
#include <mach/mach.h>

struct emb_test_thread {
    pthread_t pthread;
    thread_t mach_port;
    volatile int running;
    size_t stack_depth;
};

// Volatile local prevents tail call optimization, preserving all frames.
__attribute__((noinline))
static void recurse(volatile int *flag, size_t depth) {
    volatile size_t anchor = depth;
    if (depth > 0) {
        recurse(flag, depth - 1);
    } else {
        while (*flag) { }
    }
    (void)anchor;
}

static void *thread_entry(void *arg) {
    struct emb_test_thread *t = (struct emb_test_thread *)arg;
    recurse(&t->running, t->stack_depth);
    return NULL;
}

emb_test_thread_t emb_test_thread_create(size_t stack_depth) {
    struct emb_test_thread *t = calloc(1, sizeof(*t));
    if (t == NULL) {
        return NULL;
    }

    t->running = 1;
    t->stack_depth = stack_depth;

    if (pthread_create(&t->pthread, NULL, thread_entry, t) != 0) {
        free(t);
        return NULL;
    }

    // Let the thread settle into its spin loop.
    usleep(50000);
    t->mach_port = pthread_mach_thread_np(t->pthread);

    return t;
}

thread_t emb_test_thread_get_port(emb_test_thread_t t) {
    return t->mach_port;
}

void emb_test_thread_destroy(emb_test_thread_t t) {
    t->running = 0;
    pthread_join(t->pthread, NULL);
    free(t);
}

#endif /* !TARGET_OS_WATCH */
