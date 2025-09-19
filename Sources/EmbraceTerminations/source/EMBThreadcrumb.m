
/*
 EMBThreadcrumb forces a distinctive stack shape by dispatching through per-character functions,
 creating a reliable stack imprint of a message string to capture a stack for later symbolication.

 High-level flow:

 - init creates a detached pthread running a worker method that waits to be signaled.
 - log: sanitizes the input message to allowed characters, stores it, and signals the worker.
 - The worker thread sets its thread name (for debugging) and dispatches into a chain of functions,
   one per character of the message.
 - The end function captures the current stack trace, prunes known runtime frames, signals completion,
   and then parks on a semaphore waiting for the next log or dealloc.

 No functional code changes are included here.
*/

#import "EMBThreadcrumb.h"

#import <dispatch/dispatch.h>
#import <pthread.h>

#import <ctype.h>
#import <execinfo.h>
#import <stdio.h>
#import <string.h>

// Private ivar block for EMBThreadcrumb.
// _message: owns the UTF8 storage backing _data.
// _data: non-owning pointer to UTF8 string, valid while _message unchanged.
// _symbolDirectory: currently unused placeholder.
// _semaphore: used to start work and to park the worker thread.
// _thread: the detached pthread worker.
// _lock: mutex guarding shared mutable state.
// _index: current position in _data while dispatching.
// _stackSemaphore: one-shot completion signal per log operation.
// _stackAddresses: the captured and pruned stack backtrace.
@interface EMBThreadcrumb () {
   @public
    NSString *_message;  // Owns the UTF8 storage backing _data
    char *_data;         // Non-owning pointer valid while _message is unchanged

    NSURL *_symbolDirectory;          // Currently unused
    dispatch_semaphore_t _semaphore;  // Used both to start work and to park thread
    pthread_t _thread;                // Detached worker thread
    NSLock *_lock;                    // Guards shared mutable state

    NSUInteger _index;                     // Current position in _data
    dispatch_semaphore_t _stackSemaphore;  // One-shot completion signal per log
    NSArray<NSNumber *> *_stackAddresses;  // Captured, pruned stack trace
}
@end

// Prevent inlining and tail-call optimizations on functions to keep their frames in the stacktrace.
// This ensures each per-character function call appears as a distinct frame for symbolication.
#define EMB_KEEP_FUNCTION_IN_STACKTRACE __attribute__((disable_tail_calls))

// Prevent inlining to preserve distinct stack frames for each function.
#define EMB_NOINLINE __attribute__((noinline))

// Extra belt-and-braces inline assembly to prevent tail-call optimization, ensuring frames remain.
#define EMB_THWART_TAIL_CALL_OPTIMISATION __asm__ __volatile__("");

// Each character in the allowed alphabet maps to a unique function with a distinct symbol.
// This per-character dispatch imprints the message into the stack by chaining calls.
typedef void (*crumb_func_t)(EMBThreadcrumb *self);

// Forward declare the lookup function.
static crumb_func_t lookup(char c);

/**
 The symbol file contains:
 - `__impact_threadcrumb_end__`
 - ...
 - `__impact_threadcrumb_start__`
 - `_pthread_start`

 A crash report will typically have:
 - `semaphore_wait_trap`
 - `_dispatch_sema4_wait`
 - `_dispatch_semaphore_wait_slow`
 - `__impact_threadcrumb_end__`
 - ...
 - `__impact_threadcrumb_start__`
 - `_pthread_start`

 The stacksym file is named after a hash of the addresses above.

 We drop frame 0 (the current function) and the next 3 frames (`semaphore_wait_trap`, `_dispatch_sema4_wait`,
 `_dispatch_semaphore_wait_slow`) when symbolizing from a crash to remove runtime waiter frames that obscure the stack.
 */
static EMB_NOINLINE void __impact_threadcrumb_end__(EMBThreadcrumb *self) EMB_KEEP_FUNCTION_IN_STACKTRACE
{
    // Short-stack guard: drop current + 3 runtime frames to get meaningful stack.
    [self->_lock lock];
    NSArray<NSNumber *> *stack = [NSThread.callStackReturnAddresses copy];
    NSUInteger count = stack.count;
    if (count > 4) {
        self->_stackAddresses = [[stack subarrayWithRange:NSMakeRange(1, count - 4)] copy];
    } else {
        self->_stackAddresses = stack;
    }
    [self->_lock unlock];

    // Signal that iteration and stack capture are done.
    dispatch_semaphore_signal(self->_stackSemaphore);

    // Park the thread indefinitely until next log or dealloc.
    dispatch_semaphore_wait(self->_semaphore, DISPATCH_TIME_FOREVER);

    EMB_THWART_TAIL_CALL_OPTIMISATION
}

#define REG(c, cc)                                                                                   \
    static EMB_NOINLINE void __impact__##c##__(EMBThreadcrumb *self) EMB_KEEP_FUNCTION_IN_STACKTRACE \
    {                                                                                                \
        /* Terminate when end of C string is reached */                                              \
        if (self->_data[self->_index] == 0) {                                                        \
            __impact_threadcrumb_end__(self);                                                        \
            return;                                                                                  \
        }                                                                                            \
        /* Advance to next character before dispatching */                                           \
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

// Lookup table mapping ASCII character to function pointer for the per-character dispatch.
// Linear scan is used given the small alphabet; could be swapped for a 256-entry direct table if needed.
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

// O(n) lookup to find the function pointer for a given character.
// Returns NULL if character is unsupported, which triggers termination of dispatch.
static crumb_func_t lookup(char c)
{
    for (size_t i = 0; i < sizeof(gThreadCrumbTable) / sizeof(gThreadCrumbTable[0]); i++) {
        if (gThreadCrumbTable[i].c == c) {
            return gThreadCrumbTable[i].func;
        }
    }
    return NULL;
}

/**
 Worker thread lifecycle:

 - Waits initially on _semaphore to start work.
 - Loops while not cancelled.
 - Sets its thread name to _data (truncated by system to ~63 bytes).
 - Begins dispatch at first character of _data, chaining into per-character functions.
 - When end of string reached, stacks are captured and thread parks on _semaphore.
 - Waits for next log or dealloc to resume.
 */
static EMB_NOINLINE void *__impact_threadcrumb_start__(void *arg) EMB_KEEP_FUNCTION_IN_STACKTRACE
{
    EMBThreadcrumb *self = (__bridge EMBThreadcrumb *)(arg);

    // First wait here; subsequent wait points are at __impact_threadcrumb_end__.
    dispatch_semaphore_wait(self->_semaphore, DISPATCH_TIME_FOREVER);

    while (!NSThread.currentThread.cancelled) {
        // Thread name length limit about 64 bytes; system truncates silently.
        pthread_setname_np(self->_data);

        crumb_func_t func = lookup(self->_data[0]);
        self->_index++;
        func(self);

        // If we get here, a new log is expected and the thread loops back to wait.
    }
    EMB_THWART_TAIL_CALL_OPTIMISATION
    return NULL;
}

// EMBThreadcrumb class: manages the threadcrumb stack capturing workflow.
// Uses single-flight semantics: one log: call at a time.
// _stackSemaphore is per-call and not safe for concurrent log: invocations.
@implementation EMBThreadcrumb

- (instancetype)init
{
    /*
     Initialize:
     - Create two dispatch semaphores: _semaphore for thread start/park, _stackSemaphore for completion.
     - Create a lock to guard mutable state.
     - Create a detached pthread running __impact_threadcrumb_start__ as worker.
     - Detached used because thread spends most of its life parked and is cancelled in dealloc.
    */
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
    // Cancel the pthread and signal _semaphore to unblock if parked.
    pthread_cancel(_thread);
    dispatch_semaphore_signal(_semaphore);
}

/**
 log: entry point:

 - Sanitizes message to allowed alphabet.
 - Sets _message (owning string) and _data (non-owning UTF8 pointer).
 - Resets _index and _stackAddresses.
 - Signals worker thread to start dispatching.
 - Waits for _stackSemaphore for completion.
 - Returns the captured pruned stack.
 */
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

    // _data points into _message's UTF8 storage; must not be used after _message changes.
    _data = (char *)_message.UTF8String;
    _index = 0;
    _stackAddresses = nil;
    [self->_lock unlock];

    // Signal worker thread to start processing the message.
    dispatch_semaphore_signal(self->_semaphore);

    // Wait for worker thread to signal completion.
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

