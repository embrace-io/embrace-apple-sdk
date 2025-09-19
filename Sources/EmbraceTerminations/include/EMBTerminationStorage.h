//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#ifndef EMBTerminationStorage_h
#define EMBTerminationStorage_h

#import <Foundation/Foundation.h>
@import KSCrashRecording;

#import <EMBTerminationStorageStruct.h>

/**
 * Termination storage API
 *
 * Provides C functions to manage per-identifier termination storage records used by Embrace to persist
 * state across abnormal terminations and crashes. These functions are C-callable for use in low-level
 * contexts (e.g., crash handlers) and expose Swift-friendly names via NS_SWIFT_NAME.
 *
 * Thread-safety: Unless otherwise noted, functions are thread-safe. Avoid performing blocking work in
 * exception/crash callbacks. Prefer small, deterministic operations.
 */

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Types

/**
 * A block invoked to mutate a termination storage instance in-place.
 *
 * The provided storage is valid only for the duration of the call.
 */
typedef void (^EMBTerminationStorageUpdateBlock)(EMBTerminationStorage *storage);

#pragma mark - Public API

/**
 * Opens the shared termination storage for mutation and optionally acquires a lock.
 *
 * @param canLock Indicates whether the caller may acquire a lock. Set to NO when called from a signal
 *               or unsafe context where locking could deadlock.
 * @param block   Optional mutation block. If nil, the function ensures storage is initialized.
 */
FOUNDATION_EXTERN
void EMBTerminationStorageUpdate(BOOL canLock, EMBTerminationStorageUpdateBlock _Nullable block);

/**
 * Retrieves a termination storage snapshot for a given identifier.
 *
 * @param identifier Unique identifier for the storage record.
 * @param outStorage Output parameter populated on success.
 * @return YES if a record exists and outStorage was populated; NO otherwise.
 */
FOUNDATION_EXTERN
BOOL EMBTerminationStorageForIdentifier(NSString *identifier, EMBTerminationStorage *outStorage);

/**
 * Removes the termination storage record for a given identifier.
 *
 * @param identifier Unique identifier for the storage record.
 * @return YES if a record was removed; NO if no record existed.
 */
FOUNDATION_EXTERN
BOOL EMBTerminationStorageRemoveForIdentifier(NSString *identifier);

/**
 * Returns all known termination storage identifiers.
 */
FOUNDATION_EXTERN
NSArray<NSString *> *EMBTerminationStorageGetIdentifiers(void);

#pragma mark - Private API

/**
 * Private: Invoked by the crash pipeline before writing a crash event to allow the storage to persist
 * relevant information. Not intended for public use.
 *
 * Constraints: This function is called in a crash/exception context. Do not perform any allocations,
 * locking, or non-reentrant operations.
 */
FOUNDATION_EXTERN
void EMBTerminationStorageWillWriteCrashEvent(KSCrash_ExceptionHandlingPlan *const plan,
                                              const struct KSCrash_MonitorContext *context);

NS_ASSUME_NONNULL_END

#endif  // EMBTerminationStorage_h
