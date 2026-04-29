//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#include "emb_test_thread.h"

#if !TARGET_OS_WATCH

#include <pthread.h>
#include <stdlib.h>
#include <mach/mach.h>

struct emb_test_thread {
    pthread_t pthread;
    thread_t mach_port;
    volatile int running;
    size_t stack_depth;
    pthread_mutex_t ready_mutex;
    pthread_cond_t ready_cond;
    int ready;
};

// Volatile local prevents tail call optimization, preserving all frames.
__attribute__((noinline))
static void recurse(struct emb_test_thread *t, size_t depth) {
    volatile size_t anchor = depth;
    if (depth > 0) {
        recurse(t, depth - 1);
    } else {
        pthread_mutex_lock(&t->ready_mutex);
        t->ready = 1;
        pthread_cond_signal(&t->ready_cond);
        pthread_mutex_unlock(&t->ready_mutex);
        while (t->running) { }
    }
    (void)anchor;
}

static void *thread_entry(void *arg) {
    struct emb_test_thread *t = (struct emb_test_thread *)arg;
    recurse(t, t->stack_depth);
    return NULL;
}

emb_test_thread_t emb_test_thread_create(size_t stack_depth) {
    struct emb_test_thread *t = calloc(1, sizeof(*t));
    if (t == NULL) {
        return NULL;
    }

    t->running = 1;
    t->stack_depth = stack_depth;
    t->ready = 0;
    pthread_mutex_init(&t->ready_mutex, NULL);
    pthread_cond_init(&t->ready_cond, NULL);

    if (pthread_create(&t->pthread, NULL, thread_entry, t) != 0) {
        pthread_mutex_destroy(&t->ready_mutex);
        pthread_cond_destroy(&t->ready_cond);
        free(t);
        return NULL;
    }

    pthread_mutex_lock(&t->ready_mutex);
    while (!t->ready) {
        pthread_cond_wait(&t->ready_cond, &t->ready_mutex);
    }
    pthread_mutex_unlock(&t->ready_mutex);

    t->mach_port = pthread_mach_thread_np(t->pthread);
    return t;
}

thread_t emb_test_thread_get_port(emb_test_thread_t t) {
    return t->mach_port;
}

void emb_test_thread_destroy(emb_test_thread_t t) {
    t->running = 0;
    pthread_join(t->pthread, NULL);
    pthread_mutex_destroy(&t->ready_mutex);
    pthread_cond_destroy(&t->ready_cond);
    free(t);
}

#endif /* !TARGET_OS_WATCH */
