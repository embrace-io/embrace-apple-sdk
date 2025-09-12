//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

@import Foundation;
@import KSCrashRecording;

#import "EMBTerminationStorageStruct.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^EMBTerminationStorageUpdateBlock)(EMBTerminationStorage *_Nonnull storage);
FOUNDATION_EXTERN
void EMBTerminationStorageUpdate(BOOL canLock, EMBTerminationStorageUpdateBlock _Nullable block);

FOUNDATION_EXTERN
BOOL EMBTerminationStorageForIdentifier(NSString *_Nonnull identifier, EMBTerminationStorage *_Nonnull outStorage);

FOUNDATION_EXTERN
BOOL EMBTerminationStorageRemoveForIdentifier(NSString *_Nonnull identifier);

FOUNDATION_EXTERN
NSArray<NSString *> *_Nonnull EMBTerminationStorageGetIdentifiers(void);

/** Private callback to write data on exceptions */
FOUNDATION_EXTERN
void EMBTerminationStorageWillWriteCrashEvent(KSCrash_ExceptionHandlingPlan *_Nonnull const plan,
                                              const struct KSCrash_MonitorContext *_Nonnull context);

NS_ASSUME_NONNULL_END
