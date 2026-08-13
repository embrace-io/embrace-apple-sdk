//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#ifndef EMB_SUSPEND_WINDOW_SENTINEL_H
#define EMB_SUSPEND_WINDOW_SENTINEL_H

#include <stdint.h>

/// A test-only tripwire that proves the thread-suspend backtrace window performs **no heap
/// allocation**. Allocating between `thread_suspend` and `thread_resume` risks a whole-process
/// deadlock if the suspended thread holds the allocator lock (the "#423" class of bug).
///
/// Mechanism: while armed, it observes every allocation in the process via `malloc_logger`. Any
/// allocation made **on the window thread** while a window is open is recorded as a violation. The
/// observer only touches lock-free atomics, so it never allocates or locks itself.
///
/// Usage: `Arm()` once, bracket the window with `BeginWindow()`/`EndWindow()` from the walking
/// thread, then assert `ViolationCount()` is zero. Always pair with a positive-control test that
/// deliberately allocates inside a window and asserts the count rises — otherwise a zero could just
/// mean the mechanism isn't firing.

#ifdef __cplusplus
extern "C" {
#endif

/// Installs the process-wide allocation observer. Idempotent; saves any previous `malloc_logger`.
void EMBSuspendWindowSentinelArm(void);

/// Removes the observer, restores the previous `malloc_logger`, and clears window state. Idempotent.
void EMBSuspendWindowSentinelDisarm(void);

/// Opens the forbidden window and binds it to the **calling** thread. Allocations on that thread
/// until `EndWindow()` are counted as violations. Only atomics run here — safe to call in-window.
void EMBSuspendWindowSentinelBeginWindow(void);

/// Closes the forbidden window.
void EMBSuspendWindowSentinelEndWindow(void);

/// Allocations observed on the window thread while a window was open, since the last reset.
uint64_t EMBSuspendWindowSentinelViolationCount(void);

/// Resets the violation counter to zero.
void EMBSuspendWindowSentinelResetViolations(void);

#ifdef __cplusplus
}
#endif

#endif /* EMB_SUSPEND_WINDOW_SENTINEL_H */
