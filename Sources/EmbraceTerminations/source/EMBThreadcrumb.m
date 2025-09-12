
#import "EMBThreadcrumb.h"

#import <dispatch/dispatch.h>
#import <pthread.h>

#import <ctype.h>
#import <execinfo.h>
#import <stdio.h>
#import <string.h>

@interface EMBThreadcrumb () {
   @public
    NSString *_message;
    char *_data;  // easy access to _message, do not free, = to _message.UTF8String

    NSURL *_symbolDirectory;
    dispatch_semaphore_t _semaphore;
    pthread_t _thread;
    NSLock *_lock;

    // mutable
    NSUInteger _index;
    dispatch_semaphore_t _stackSemaphore;
    NSArray<NSNumber *> *_stackAddresses;
}
@end

// Disables optimisations to ensure a function remains in stacktrace.
#define EMB_KEEP_FUNCTION_IN_STACKTRACE __attribute__((disable_tail_calls))

// Disables inline optimisation.
#define EMB_NOINLINE __attribute__((noinline))

// Extra safety measure to ensure a method is not tail-call optimised.
#define EMB_THWART_TAIL_CALL_OPTIMISATION __asm__ __volatile__("");

typedef struct {
    char message[PATH_MAX];
    char symbolDirectory[PATH_MAX];
    dispatch_semaphore_t semaphore;
    pthread_t thread;

    // mutable
    size_t index;
} ImpactStorageThreadData;

typedef void (*crumb_func_t)(EMBThreadcrumb *self);
static crumb_func_t lookup(char c);

/**

 The symbol file contains:
 - `__impact_threadcrumb_end__`
 - ...
 - `__impact_threadcrumb_start__`
 - `_pthread_start`

 A crash report will contain:
 - `semaphore_wait_trap`
 - `_dispatch_sema4_wait`
 - `_dispatch_semaphore_wait_slow`
 - `__impact_threadcrumb_end__`
 - ...
 - `__impact_threadcrumb_start__`
 - `_pthread_start`

 In stacksym file will be named after a hash of the addresses above.
 We'll need to remove the top 3 symbols/addresses in order to symbolicate
 from a crash.
 */

static EMB_NOINLINE void __impact_threadcrumb_end__(EMBThreadcrumb *self) EMB_KEEP_FUNCTION_IN_STACKTRACE
{
    // take a trace of this stack
    // so we can save it to disk for
    // local symbolication
    [self->_lock lock];
    NSArray<NSNumber *> *stack = [NSThread.callStackReturnAddresses copy];
    self->_stackAddresses = [[stack subarrayWithRange:NSMakeRange(1, stack.count - 4)] copy];
    [self->_lock unlock];

    // tell the class we're done iterating and have a stack
    dispatch_semaphore_signal(self->_stackSemaphore);

    // now just wait forever
    dispatch_semaphore_wait(self->_semaphore, DISPATCH_TIME_FOREVER);

    EMB_THWART_TAIL_CALL_OPTIMISATION
}

#define REG(c, cc)                                                                                   \
    static EMB_NOINLINE void __impact__##c##__(EMBThreadcrumb *self) EMB_KEEP_FUNCTION_IN_STACKTRACE \
    {                                                                                                \
        if (self->_data[self->_index] == 0) {                                                        \
            __impact_threadcrumb_end__(self);                                                        \
            return;                                                                                  \
        }                                                                                            \
        crumb_func_t func = lookup(self->_data[self->_index]);                                       \
        self->_index++;                                                                              \
        if (func) {                                                                                  \
            func(self);                                                                              \
        } else {                                                                                     \
            __impact_threadcrumb_end__(self);                                                        \
            return;                                                                                  \
        }                                                                                            \
        EMB_THWART_TAIL_CALL_OPTIMISATION                                                            \
    }

REG(A, 'A')
REG(B, 'B')
REG(C, 'C')
REG(D, 'D')
REG(E, 'E')
REG(F, 'F')
REG(G, 'G')
REG(H, 'H')
REG(I, 'I')
REG(J, 'J')
REG(K, 'K')
REG(L, 'L')
REG(M, 'M')
REG(N, 'N')
REG(O, 'O')
REG(P, 'P')
REG(Q, 'Q')
REG(R, 'R')
REG(S, 'S')
REG(T, 'T')
REG(U, 'U')
REG(V, 'V')
REG(W, 'W')
REG(X, 'X')
REG(Y, 'Y')
REG(Z, 'Z')
REG(_, '_')
REG(a, 'a')
REG(b, 'b')
REG(c, 'c')
REG(d, 'd')
REG(e, 'e')
REG(f, 'f')
REG(g, 'g')
REG(h, 'h')
REG(i, 'i')
REG(j, 'j')
REG(k, 'k')
REG(l, 'l')
REG(m, 'm')
REG(n, 'n')
REG(o, 'o')
REG(p, 'p')
REG(q, 'q')
REG(r, 'r')
REG(s, 's')
REG(t, 't')
REG(u, 'u')
REG(v, 'v')
REG(w, 'w')
REG(x, 'x')
REG(y, 'y')
REG(z, 'z')
REG(0, '0')
REG(1, '1')
REG(2, '2')
REG(3, '3')
REG(4, '4')
REG(5, '5')
REG(6, '6')
REG(7, '7')
REG(8, '8')
REG(9, '9')

#undef REG

typedef struct {
    crumb_func_t func;
    char c;
} ThreadCrumbEntry;

#define REG(c, cc) { (void *)&__impact__##c##__, cc },

ThreadCrumbEntry gThreadCrumbTable[] = {
    REG(A, 'A') REG(B, 'B') REG(C, 'C') REG(D, 'D') REG(E, 'E') REG(F, 'F') REG(G, 'G') REG(H, 'H') REG(I, 'I')
        REG(J, 'J') REG(K, 'K') REG(L, 'L') REG(M, 'M') REG(N, 'N') REG(O, 'O') REG(P, 'P') REG(Q, 'Q') REG(R, 'R')
            REG(S, 'S') REG(T, 'T') REG(U, 'U') REG(V, 'V') REG(W, 'W') REG(X, 'X') REG(Y, 'Y') REG(Z, 'Z') REG(_, '_')
                REG(a, 'a') REG(b, 'b') REG(c, 'c') REG(d, 'd') REG(e, 'e') REG(f, 'f') REG(g, 'g') REG(h, 'h')
                    REG(i, 'i') REG(j, 'j') REG(k, 'k') REG(l, 'l') REG(m, 'm') REG(n, 'n') REG(o, 'o') REG(p, 'p')
                        REG(q, 'q') REG(r, 'r') REG(s, 's') REG(t, 't') REG(u, 'u') REG(v, 'v') REG(w, 'w') REG(x, 'x')
                            REG(y, 'y') REG(z, 'z') REG(0, '0') REG(1, '1') REG(2, '2') REG(3, '3') REG(4, '4')
                                REG(5, '5') REG(6, '6') REG(7, '7') REG(8, '8') REG(9, '9')

};

#undef REG

static crumb_func_t lookup(char c)
{
    for (size_t i = 0; i < sizeof(gThreadCrumbTable) / sizeof(gThreadCrumbTable[0]); i++) {
        if (gThreadCrumbTable[i].c == c) {
            return gThreadCrumbTable[i].func;
        }
    }
    return NULL;
}

static EMB_NOINLINE void *__impact_threadcrumb_start__(void *arg) EMB_KEEP_FUNCTION_IN_STACKTRACE
{
    EMBThreadcrumb *self = (__bridge EMBThreadcrumb *)(arg);

    // the first wait is here, the others are at the end of the log
    dispatch_semaphore_wait(self->_semaphore, DISPATCH_TIME_FOREVER);

    while (NSThread.currentThread.executing && !NSThread.currentThread.cancelled) {
        if (!NSThread.currentThread.executing) {
            break;
        }
        if (NSThread.currentThread.cancelled) {
            break;
        }

        pthread_setname_np(self->_data);

        crumb_func_t func = lookup(self->_data[0]);
        self->_index++;
        func(self);

        // if we hit this spot, it's because there's a new log coming in.
    }
    EMB_THWART_TAIL_CALL_OPTIMISATION
    return NULL;
}

@implementation EMBThreadcrumb

- (instancetype)init
{
    if (self = [super init]) {
        _semaphore = dispatch_semaphore_create(0);
        _stackSemaphore = dispatch_semaphore_create(0);
        _lock = [NSLock new];

        pthread_attr_t attr = { 0 };
        pthread_attr_init(&attr);
        pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
        pthread_create(&_thread, &attr, __impact_threadcrumb_start__, (__bridge void *)self);
        pthread_attr_destroy(&attr);
    }
    return self;
}

- (void)dealloc
{
    pthread_cancel(_thread);
    dispatch_semaphore_signal(_semaphore);
}

- (NSArray<NSNumber *> *)log:(NSString *)message
{
    static NSCharacterSet *sDisallowedCharacters;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSCharacterSet *set = [NSCharacterSet
            characterSetWithCharactersInString:@"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"];
        sDisallowedCharacters = [set invertedSet];
    });

    [self->_lock lock];
    _message = [[message componentsSeparatedByCharactersInSet:sDisallowedCharacters] componentsJoinedByString:@""];
    _data = (char *)_message.UTF8String;
    _index = 0;
    _stackAddresses = nil;
    [self->_lock unlock];

    // signal the thread to start iterating and logging in the thread
    dispatch_semaphore_signal(self->_semaphore);

    // wait for it to be done before returning
    dispatch_semaphore_wait(self->_stackSemaphore, DISPATCH_TIME_FOREVER);

    NSArray<NSNumber *> *stack;
    {
        [self->_lock lock];
        stack = [self->_stackAddresses copy];
        [self->_lock unlock];
    }

    return stack ? stack : @[];
}

@end
