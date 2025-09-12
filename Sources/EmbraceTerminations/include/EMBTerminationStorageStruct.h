//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// This structure is for efficient fast writes to a mmap'd
// file. Keep the struct naturally aligned and padded.
// Do not reorder members as this struct is as-is on disk, only add to the end.
//
// WARNING: If you add fields, please add them at the end
// and add an `ASSERT_OFFSET` as well in order to statically
// assert data.

#ifndef EMB_SMALL_BUFFER_SIZE
#define EMB_SMALL_BUFFER_SIZE 1024
#endif

#ifndef EMB_LARGE_BUFFER_SIZE
#define EMB_LARGE_BUFFER_SIZE 4096
#endif

#pragma pack(push, 8)
typedef struct __attribute__((aligned(8))) {
    //
    // - Start Version 1 -
    //

    // magic
    uint64_t magic;  // Must be kEMBTerminationStorageMagic

    // version
    uint64_t version;

    // creation time
    uint64_t creationTimestampMonotonicMillis;
    uint64_t creationTimestampEpochMillis;

    // timestamp
    uint64_t updateTimestampMonotonicMillis;

    // process id
    uuid_t uuid;
    pid_t pid;

    // - CRASH DATA SECTION --

    // basic info
    uint8_t stackOverflow;
    uintptr_t address;

    // clean exit
    uint8_t cleanExitSet;
    uint8_t exitCalled;
    uint8_t quickExitCalled;
    uint8_t terminateCalled;

    // exception
    uint8_t exceptionSet;
    uint8_t exceptionType;  // 0 objc, 1 cpp
    char exceptionName[EMB_SMALL_BUFFER_SIZE];
    char exceptionReason[EMB_LARGE_BUFFER_SIZE];
    char exceptionUserInfo[EMB_LARGE_BUFFER_SIZE];

    // mach exception
    uint8_t machExceptionSet;
    int64_t machExceptionNumber;
    int64_t machExceptionCode;
    int64_t machExceptionSubcode;

    // signal
    uint8_t signalSet;
    int64_t signalNumber;
    int64_t signalCode;

    // app info
    uint8_t appTransitionState;  // KSCrashAppTransitionState

    // app memory
    uint64_t memoryFootprint;
    uint64_t memoryRemaining;
    uint64_t memoryLimit;
    uint8_t memoryLevel;     // KSCrashAppMemoryState
    uint8_t memoryPressure;  // KSCrashAppMemoryState

    //
    // - End Version 1 -
    //

} EMBTerminationStorage;
#pragma pack(pop)

//_Static_assert(sizeof(EMBTerminationStorage) == 9344, "Unexpected struct size");
_Static_assert(__alignof__(EMBTerminationStorage) == 8, "Unexpected struct alignment");

#define ASSERT_OFFSET(field, offset) \
    _Static_assert(offsetof(EMBTerminationStorage, field) == offset, #field " offset incorrect")

/*
ASSERT_OFFSET(magic, 0);
ASSERT_OFFSET(version, 8);
ASSERT_OFFSET(timestamp_mono_ms, 16);
ASSERT_OFFSET(timestamp_epoch_ms, 24);
ASSERT_OFFSET(cleanExitSet, 32);
ASSERT_OFFSET(exitCalled, 33);
ASSERT_OFFSET(quickExitCalled, 34);
ASSERT_OFFSET(terminateCalled, 35);
ASSERT_OFFSET(exceptionSet, 36);
ASSERT_OFFSET(exceptionType, 37);
ASSERT_OFFSET(exceptionName, 38);
ASSERT_OFFSET(exceptionReason, 293);
ASSERT_OFFSET(machExceptionSet, 548);
ASSERT_OFFSET(machExceptionNumber, 552);
ASSERT_OFFSET(machExceptionCode, 560);
ASSERT_OFFSET(machExceptionSubcode, 568);
ASSERT_OFFSET(signalSet, 576);
ASSERT_OFFSET(signalNumber, 584);
ASSERT_OFFSET(signalCode, 592);
ASSERT_OFFSET(signalErrorNumber, 600);
ASSERT_OFFSET(signalExitStatus, 608);
ASSERT_OFFSET(signalFaultInstructionAddress, 616);
*/

extern const uint64_t kEMBTerminationStorageVersion_1;
extern const uint64_t kEMBTerminationStorageCurrentVersion;

extern const uint64_t kEMBTerminationStorageMagic;

NS_ASSUME_NONNULL_END
