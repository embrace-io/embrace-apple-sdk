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

/** Private callback to write data on exceptions */
FOUNDATION_EXTERN
BOOL EMBTerminationStorageShouldWriteReport(const struct KSCrash_MonitorContext *_Nullable context);

NS_ASSUME_NONNULL_END
