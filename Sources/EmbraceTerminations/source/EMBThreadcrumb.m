
/*
 EMBThreadcrumb
 --------------
 A low-level utility that encodes a short message into a thread's call stack so the message
 can be recovered later from crash reports via symbolication.

 Concept
 - Map each allowed character to a unique function symbol.
 - Invoke those functions in sequence to shape the stack so it mirrors the message.
 - Capture the stack when the sequence ends, then park the worker thread until the next request.

 Why
 - Crash reports often lack high-level context. By imprinting a message directly in the stack,
   you can recover identifiers (like request IDs or breadcrumbs) from post-mortem stacks alone.

 How it works (high level)
 - A dedicated pthread waits for a signal. When a message arrives, it sets a debug name and walks
   a function-per-character chain derived from the sanitized message.
 - Inlining and tail calls are disabled so each function appears as a distinct frame.
 - The terminal handler captures the stack, prunes well-known runtime wait frames, signals completion,
   and parks until the next message or shutdown.

 Guarantees
 - Only characters in [A–Z, a–z, 0–9, _] are encoded to ensure stable symbol names.
 - Messages longer than EMBThreadcrumbMaximumMessageLength are truncated.
 - Calls to `log:` are serialized within an instance (single-flight).

 Limitations
 - Depends on stack behavior and symbol visibility; treat as a low-level diagnostic tool.
 - The exact runtime wait frames pruned may vary with OS/libdispatch versions.
 - Not designed for concurrent `log:` calls; use one instance per logging context if needed.
*/

#import "EMBThreadcrumb.h"

#import <dispatch/dispatch.h>
#import <pthread.h>

#import <ctype.h>
#import <stdatomic.h>
#import <stdio.h>
#import <string.h>

// Maximum size of a message that can be logged until it is truncated.
NSInteger const EMBThreadcrumbMaximumMessageLength = 512;

@interface EMBThreadcrumb () {
   @public
    NSString *_message;
    char *_data;  // Copy of the message. allocated to EMBThreadcrumbMaximumMessageLength+1 length

    dispatch_semaphore_t _semaphore;  // Used both to start work and to park thread
    pthread_t _thread;
    BOOL _threadCreationFailed;
    NSLock *_lock;  // Guards shared mutable state

    NSUInteger _index;                     // Current position in _data
    dispatch_semaphore_t _stackSemaphore;  // One-shot completion signal per log
    NSArray<NSNumber *> *_stackAddresses;  // Captured, pruned stack trace
    atomic_bool _stopped;
}
@end

// Prevent optimizer from removing frames so the stack reliably encodes the message.
#define EMB_KEEP_FUNCTION_IN_STACKTRACE __attribute__((disable_tail_calls))

// Prevent inlining to preserve distinct stack frames for each function.
#define EMB_NOINLINE __attribute__((noinline))

// Extra belt-and-braces inline assembly to prevent tail-call optimization, ensuring frames remain.
#define EMB_THWART_TAIL_CALL_OPTIMISATION __asm__ __volatile__("");

// Function type for per-character stack-imprinting handlers.
typedef void (*crumb_func_t)(EMBThreadcrumb *self);

// Forward declare the lookup function.
static crumb_func_t lookup(char c);

/**
 Terminal handler for the per-character chain.
 - Capture the current stack, drop a few known runtime wait frames, signal completion, and park.
 - Adjust pruning if symbolication shows unexpected runtime frames at the tail.
*/
static EMB_NOINLINE void __emb_threadcrumb_end__(EMBThreadcrumb *self) EMB_KEEP_FUNCTION_IN_STACKTRACE
{
    // Short-stack guard: drop current + 3 runtime frames to get meaningful stack.
    NSArray<NSNumber *> *stack = [NSThread.callStackReturnAddresses copy];
    NSUInteger count = stack.count;
    if (count > 4) {
        self->_stackAddresses = [[stack subarrayWithRange:NSMakeRange(1, count - 4)] copy];
    } else {
        self->_stackAddresses = @[];
    }

    // Signal that iteration and stack capture are done.
    dispatch_semaphore_signal(self->_stackSemaphore);

    // Park the thread indefinitely until next log or dealloc.
    dispatch_semaphore_wait(self->_semaphore, DISPATCH_TIME_FOREVER);

    EMB_THWART_TAIL_CALL_OPTIMISATION
}

#define CALL_NEXT_OR_END                                   \
    /* Advance to next character before dispatching */     \
    crumb_func_t func = lookup(self->_data[self->_index]); \
    self->_index++;                                        \
    if (func) {                                            \
        func(self);                                        \
    } else {                                               \
        __emb_threadcrumb_end__(self);                     \
    }

#define REG(c, cc)                                                                                \
    static EMB_NOINLINE void __emb__##c##__(EMBThreadcrumb *self) EMB_KEEP_FUNCTION_IN_STACKTRACE \
    {                                                                                             \
        /* Terminate when end of C string is reached */                                           \
        if (self->_data[self->_index] == 0) {                                                     \
            __emb_threadcrumb_end__(self);                                                        \
            return;                                                                               \
        }                                                                                         \
        CALL_NEXT_OR_END                                                                          \
        EMB_THWART_TAIL_CALL_OPTIMISATION                                                         \
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
typedef struct {
    crumb_func_t func;
    char c;
} ThreadCrumbEntry;

#define REG(c, cc) { (void *)&__emb__##c##__, cc },

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

static crumb_func_t sDirectFunctionLookup[256] = { 0 };

// Populate an O(1) ASCII->function map for fast per-character dispatch.
static void _initLookupTable(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        for (size_t i = 0; i < sizeof(gThreadCrumbTable) / sizeof(gThreadCrumbTable[0]); i++) {
            sDirectFunctionLookup[(unsigned char)gThreadCrumbTable[i].c] = gThreadCrumbTable[i].func;
        }
    });
}

// O(1) lookup to find the function pointer for a given character.
static crumb_func_t lookup(char c) { return sDirectFunctionLookup[(unsigned char)c]; }

/**
 Worker thread entry point: wait for a message, set a debug name, walk the per-character chain, then park.
*/
static EMB_NOINLINE void *__emb_threadcrumb_start__(void *arg) EMB_KEEP_FUNCTION_IN_STACKTRACE
{
    EMBThreadcrumb *self = (__bridge EMBThreadcrumb *)(arg);

    // First wait here; subsequent wait points are at __emb_threadcrumb_end__.
    dispatch_semaphore_wait(self->_semaphore, DISPATCH_TIME_FOREVER);

    while (!atomic_load(&self->_stopped)) {
        // Thread name length limit about 64 bytes; system truncates silently.
        pthread_setname_np(self->_data);
        CALL_NEXT_OR_END
        // Loop back to await the next message.
    }
    EMB_THWART_TAIL_CALL_OPTIMISATION
    return NULL;
}

// Manages the worker thread and single-flight logging that produces stack-imprinted breadcrumbs.
@implementation EMBThreadcrumb

+ (void)initialize
{
    // on first call to threadcrumb, setup a look up table
    _initLookupTable();
}

- (instancetype)init
{
    /*
     Initialize synchronization primitives, allocate the message buffer, and start a dedicated worker thread
     with a conservatively sized stack to accommodate deep per-character frames.
    */

    if (self = [super init]) {
        _semaphore = dispatch_semaphore_create(0);
        _stackSemaphore = dispatch_semaphore_create(0);
        _lock = [NSLock new];
        _data = malloc(EMBThreadcrumbMaximumMessageLength + 1);

        // calculate expected stack size and be very safe about it.
        NSUInteger pageSize = PAGE_SIZE;
        NSUInteger frameSize = 2 * 1024;  // expected frame size is 2KB.
        NSUInteger sizeForMessage = EMBThreadcrumbMaximumMessageLength * frameSize;
        NSUInteger guardSize = pageSize;
        NSUInteger expectedBytesRequired = (sizeForMessage + guardSize) * 2;  // 2 for a safe margin.
        NSUInteger pageRoundedBytes =
            MAX(((expectedBytesRequired + pageSize - 1) / pageSize) * pageSize, PTHREAD_STACK_MIN);

        pthread_attr_t attr = { 0 };
        pthread_attr_init(&attr);
        pthread_attr_setstacksize(&attr, pageRoundedBytes);
        _threadCreationFailed =
            (pthread_create(&_thread, &attr, __emb_threadcrumb_start__, (__bridge void *)self) != 0);
        pthread_attr_destroy(&attr);
    }
    return self;
}

- (void)dealloc
{
    if (!_threadCreationFailed && _thread) {
        atomic_store(&_stopped, true);
        dispatch_semaphore_signal(_semaphore);
        pthread_join(_thread, NULL);
    }

    free(_data);
}

- (NSArray<NSNumber *> *)log:(NSString *)message
{
    // Sanitize and bound the message, then trigger the worker and await the captured stack.
    static NSCharacterSet *sDisallowedCharacters;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSCharacterSet *set = [NSCharacterSet
            characterSetWithCharactersInString:@"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"];
        sDisallowedCharacters = [set invertedSet];
    });

    NSArray<NSNumber *> *stack = @[];
    {
        [self->_lock lock];
        if (_threadCreationFailed || !_thread || !_data) {
            [self->_lock unlock];
            return stack;
        }
        // Remove disallowed characters.
        _message = [[message componentsSeparatedByCharactersInSet:sDisallowedCharacters] componentsJoinedByString:@""];

        // Truncate overly long messages.
        if (_message.length > EMBThreadcrumbMaximumMessageLength) {
            _message = [_message substringToIndex:EMBThreadcrumbMaximumMessageLength];
        }

        // Copy into the C buffer for fast indexed dispatch.
        memset(_data, 0, EMBThreadcrumbMaximumMessageLength + 1);
        if (_message.UTF8String) {
            strncpy(_data, _message.UTF8String, EMBThreadcrumbMaximumMessageLength);
        }
        _index = 0;
        _stackAddresses = nil;

        // Signal worker thread to start processing the message.
        dispatch_semaphore_signal(self->_semaphore);

        // Wait for worker thread to signal completion.
        dispatch_semaphore_wait(self->_stackSemaphore, DISPATCH_TIME_FOREVER);

        // collect the stack
        stack = [self->_stackAddresses copy];

        [self->_lock unlock];
    }

    return stack ? stack : @[];
}

@end

