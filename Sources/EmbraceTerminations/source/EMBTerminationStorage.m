//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import "EMBTerminationStorage.h"

#import <os/lock.h>
#import <stdlib.h>
#import <sys/mman.h>

@import EmbraceCommonInternal;
@import KSCrashRecording;

// MARK: - Constants

const uint64_t kEMBTerminationStorageVersion_1 = 1;
const uint64_t kEMBTerminationStorageCurrentVersion = kEMBTerminationStorageVersion_1;
const uint64_t kEMBTerminationStorageMagic = 0x45435241424D5245ULL;

NSString *const kEMBTerminationStorageExtension = @"term";

// MARK: - Statics

static os_unfair_lock sStorageLock = OS_UNFAIR_LOCK_INIT;
static EMBTerminationStorage *sStorage = NULL;

// MARK: - Exit

static void _atExit(void)
{
    EMBTerminationStorageUpdate(YES, ^(EMBTerminationStorage *_Nonnull storage) {
        storage->cleanExitSet = 1;
        storage->exitCalled = 1;
    });
}

static void _willTerminateNotification(CFNotificationCenterRef center, void *observer, CFNotificationName name,
                                       const void *object, CFDictionaryRef userInfo)
{
    EMBTerminationStorageUpdate(YES, ^(EMBTerminationStorage *_Nonnull storage) {
        storage->cleanExitSet = 1;
        storage->terminateCalled = 1;
    });
}

// MARK: - Storage Private

static inline uint64_t milliseconds(clockid_t clock) { return clock_gettime_nsec_np(clock) / 1000000; }

static inline uint64_t walltime() { return milliseconds(CLOCK_REALTIME); }

static inline uint64_t monotonic() { return milliseconds(CLOCK_MONOTONIC_RAW); }

static NSURL *rootURL()
{
    static NSURL *sRootURL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{

#if TARGET_OS_TV
        NSSearchPathDirectory searchPath = NSCachesDirectory;
#else
        NSSearchPathDirectory searchPath = NSApplicationSupportDirectory;
#endif
        NSURL *url = [NSFileManager.defaultManager URLsForDirectory:searchPath inDomains:NSUserDomainMask].firstObject;
        if (url) {
            url = [url URLByAppendingPathComponent:@"embrace.io"];
            url = [url URLByAppendingPathComponent:@"termination"];
            [[NSFileManager defaultManager] createDirectoryAtURL:url
                                     withIntermediateDirectories:YES
                                                      attributes:nil
                                                           error:nil];
            sRootURL = url;
        }
    });
    return sRootURL;
}

static bool EMBTerminationStorageLoad(NSURL *url, EMBTerminationStorage *storage)
{
    const char *path = url.path.UTF8String;

    int fd = open(path, O_RDONLY);
    if (fd == -1) {
        printf("Could not open file %s: %s\n", path, strerror(errno));
        return false;
    }

    size_t expectedSize = sizeof(EMBTerminationStorage);
    if (read(fd, storage, expectedSize) != expectedSize) {
        printf("Could not read file %s: %s\n", path, strerror(errno));
        close(fd);
        return false;
    }

    close(fd);

    if (storage->magic != kEMBTerminationStorageMagic) {
        printf("Wrong magic\n");
        return false;
    }

    if (storage->version != kEMBTerminationStorageVersion_1) {
        printf("Wrong version\n");
        return false;
    }

    // we should really validate more things here.

    return true;
}

static void *EMBTerminationStorageMap(NSURL *url, size_t size)
{
    const char *path = url.path.UTF8String;

    int fd = open(path, O_RDWR | O_CREAT | O_TRUNC, 0644);
    if (fd == -1) {
        printf("Could not open file %s: %s\n", path, strerror(errno));
        return NULL;
    }

    if (lseek(fd, size, SEEK_SET) == -1) {
        printf("Could not seek file %s: %s\n", path, strerror(errno));
        close(fd);
        unlink(path);
        return NULL;
    }

    if (write(fd, "", 1) == -1) {
        printf("Could not write file %s: %s\n", path, strerror(errno));
        close(fd);
        unlink(path);
        return NULL;
    }

    void *ptr = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);

    if (ptr == MAP_FAILED) {
        printf("Could not mmap file %s: %s\n", path, strerror(errno));
        // This comes before close which is ok since it'll happen
        // when all fd's are closed.
        unlink(path);
    }

    assert(((uintptr_t)ptr % __alignof__(EMBTerminationStorage)) == 0 && "mmap returned unaligned pointer");

    close(fd);
    return ptr;
}

static void EMBTerminationStorageLog(const EMBTerminationStorage *storage)
{
    printf("EMBTerminationStorage {\n");

    printf("  magic:                         0x%016" PRIx64 "\n", storage->magic);
    printf("  version:                       %" PRIu64 "\n", storage->version);
    printf("\n");

    printf("  creationTimestampEpochMs:      %" PRIu64 "\n", storage->creationTimestampEpochMillis);
    printf("  creationTimestampMonoMs:       %" PRIu64 "\n", storage->creationTimestampMonotonicMillis);
    printf("  updateTimestampMonoMs:         %" PRIu64 "\n", storage->updateTimestampMonotonicMillis);
    printf("\n");

    uuid_string_t uuidStr = { 0 };
    uuid_unparse(storage->uuid, uuidStr);
    printf("  uuid:                          %s\n", uuidStr);
    printf("  pid:                           %d\n", storage->pid);
    printf("\n");

    printf("  stackOverflow:                 %u\n", storage->stackOverflow);
    printf("  address:                       0x%" PRIxPTR "\n", storage->address);
    printf("\n");

    printf("  cleanExitSet:                  %u\n", storage->cleanExitSet);
    printf("  exitCalled:                    %u\n", storage->exitCalled);
    printf("  quickExitCalled:               %u\n", storage->quickExitCalled);
    printf("  terminateCalled:               %u\n", storage->terminateCalled);
    printf("\n");

    printf("  exceptionSet:                  %u\n", storage->exceptionSet);
    printf("  exceptionType:                 %u\n", storage->exceptionType);
    printf("  exceptionName:                 %.*s\n", EMB_SMALL_BUFFER_SIZE, storage->exceptionName);
    printf("  exceptionReason:               %.*s\n", EMB_LARGE_BUFFER_SIZE, storage->exceptionReason);
    printf("  exceptionUserInfo:             %.*s\n", EMB_LARGE_BUFFER_SIZE, storage->exceptionUserInfo);
    printf("\n");

    printf("  machExceptionSet:              %u\n", storage->machExceptionSet);
    printf("  machExceptionNumber:           %" PRId64 "\n", storage->machExceptionNumber);
    printf("  machExceptionCode:             %" PRId64 "\n", storage->machExceptionCode);
    printf("  machExceptionSubcode:          %" PRId64 "\n", storage->machExceptionSubcode);
    printf("\n");

    printf("  signalSet:                     %u\n", storage->signalSet);
    printf("  signalNumber:                  %" PRId64 "\n", storage->signalNumber);
    printf("  signalCode:                    %" PRId64 "\n", storage->signalCode);
    printf("\n");

    printf("  appTransitionState:            %s\n", ksapp_transitionStateToString(storage->appTransitionState));
    printf("\n");

    printf("  memoryFootprint:               %" PRId64 "\n", storage->memoryFootprint);
    printf("  memoryRemaining:               %" PRId64 "\n", storage->memoryRemaining);
    printf("  memoryLimit:                   %" PRId64 "\n", storage->memoryLimit);
    printf("  memoryLevel:                   %s\n", KSCrashAppMemoryStateToString(storage->memoryLevel));
    printf("  memoryPressure:                %s\n", KSCrashAppMemoryStateToString(storage->memoryPressure));
    printf("\n");

    printf("}\n");
}

static NSArray<NSString *> *_Nonnull fileWithExtensionInURL(NSURL *_Nonnull directoryURL, NSString *_Nonnull extension,
                                                            BOOL keepExtension)
{
    NSArray<NSString *> *allFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directoryURL.path
                                                                                        error:nil];
    if (!allFiles) {
        return @[];
    }

    NSMutableArray<NSString *> *output = [NSMutableArray array];
    for (NSString *name in allFiles) {
        if ([name.pathExtension isEqualToString:extension]) {
            [output addObject:keepExtension ? name : [name stringByDeletingPathExtension]];
        }
    }
    return output;
}

static NSURL *_Nullable mostRecentFileWithExtensionInURL(NSURL *_Nonnull directoryURL, NSString *_Nonnull extension)
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSURL *> *urls = [fm contentsOfDirectoryAtURL:directoryURL
                               includingPropertiesForKeys:nil
                                                  options:0
                                                    error:nil];
    if (!urls) return nil;

    NSURL *latestURL = nil;
    NSDate *latestDate = nil;

    for (NSURL *url in urls) {
        if (![url.pathExtension isEqualToString:extension]) {
            continue;
            ;
        }

        NSDictionary<NSFileAttributeKey, id> *attrs = [fm attributesOfItemAtPath:url.path error:nil];
        if (!attrs) continue;

        NSDate *modDate = attrs[NSFileModificationDate];
        if (!latestDate || [modDate compare:latestDate] == NSOrderedDescending) {
            latestDate = modDate;
            latestURL = url;
        }
    }

    return latestURL;
}

// MARK: - Storage Public

static BOOL EMBTerminationStorageInitialize()
{
    printf("size of storage: %lu\n", sizeof(EMBTerminationStorage));

    // Load up previous storage
    NSURL *previousStorageURL = mostRecentFileWithExtensionInURL(rootURL(), kEMBTerminationStorageExtension);
    if (previousStorageURL) {
        EMBTerminationStorage storage = { 0 };
        if (EMBTerminationStorageLoad(previousStorageURL, &storage)) {
            printf("\n----- PREVIOUS SESSION -----\n");
            EMBTerminationStorageLog(&storage);
            printf("----- -------- ------- -----\n\n");
        }
    }

    // create the new storage
    NSString *identifier = EMBCurrentProcessIdentifier.value;
    NSURL *appStorageURL = [[rootURL() URLByAppendingPathComponent:identifier]
        URLByAppendingPathExtension:kEMBTerminationStorageExtension];

    size_t size = sizeof(EMBTerminationStorage);
    void *mmapData = EMBTerminationStorageMap(appStorageURL, size);
    if (!mmapData) {
        return NO;
    }
    memset(mmapData, 0, size);

    sStorage = (EMBTerminationStorage *)mmapData;
    sStorage->magic = kEMBTerminationStorageMagic;
    sStorage->version = kEMBTerminationStorageCurrentVersion;
    sStorage->creationTimestampMonotonicMillis = monotonic();
    sStorage->creationTimestampEpochMillis = walltime();
    sStorage->updateTimestampMonotonicMillis = sStorage->creationTimestampMonotonicMillis;
    sStorage->pid = getpid();
    sStorage->appTransitionState = KSCrashAppStateTracker.sharedInstance.transitionState;

    assert(identifier.UTF8String);
    uuid_parse(identifier.UTF8String, sStorage->uuid);

    printf("[EMBTermination] process uuid: %s\n", identifier.UTF8String);

    // Ensure we get normal exits out of the way
    atexit(_atExit);

    CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL, _willTerminateNotification,
                                    CFSTR("UIApplicationWillTerminateNotification"), NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);

    // Track state
    [KSCrashAppStateTracker.sharedInstance addObserverWithBlock:^(KSCrashAppTransitionState transitionState) {
        EMBTerminationStorageUpdate(YES, ^(EMBTerminationStorage *_Nonnull storage) {
            storage->appTransitionState = transitionState;
        });
    }];

    // Track memory
    [KSCrashAppMemoryTracker.sharedInstance
        addObserverWithBlock:^(KSCrashAppMemory *_Nonnull memory, KSCrashAppMemoryTrackerChangeType changes) {
            EMBTerminationStorageUpdate(YES, ^(EMBTerminationStorage *_Nonnull storage) {
                if (changes & KSCrashAppMemoryTrackerChangeTypeFootprint) {
#define TEN_MB ((1000 * 1000) * 10)
#define ABS_DIFF(x, y) (x > y ? x - y : y - x)
                    if (ABS_DIFF(storage->memoryFootprint, memory.footprint) >= TEN_MB) {
                        storage->memoryFootprint = memory.footprint;
                        storage->memoryRemaining = memory.remaining;
                    }
                    if (storage->memoryLimit != memory.limit) {
                        storage->memoryLimit = memory.limit;
                    }
                }
                if (changes & KSCrashAppMemoryTrackerChangeTypePressure) {
                    storage->memoryPressure = memory.pressure;
                }
                if (changes & KSCrashAppMemoryTrackerChangeTypeLevel) {
                    storage->memoryLevel = memory.level;
                }
            });
        }];

    return YES;
}

void EMBTerminationStorageWillWriteCrashEvent(KSCrash_ExceptionHandlingPlan *_Nonnull const plan,
                                              const struct KSCrash_MonitorContext *_Nonnull context)
{
    if (!plan || !context) {
        return;
    }

    // Only store fatals
    if (!plan->isFatal) {
        return;
    }

    // Ensure the reporter doesn't write this crash out.
    plan->shouldWriteReport = false;
    plan->shouldRecordAllThreads = false;

    // Update everything, we can lock if we're not in an async safe callback.
    EMBTerminationStorageUpdate(plan->requiresAsyncSafety, ^(EMBTerminationStorage *_Nonnull storage) {
        storage->stackOverflow = context->isStackOverflow;
        storage->address = context->faultAddress;
        if (context->crashReason) {
            strncpy(storage->exceptionReason, context->crashReason, EMB_LARGE_BUFFER_SIZE - 1);
        }

        // mach
        if (context->mach.type != 0) {
            storage->machExceptionSet = 1;
            storage->machExceptionCode = context->mach.type;
            storage->machExceptionNumber = context->mach.code;
            storage->machExceptionSubcode = context->mach.subcode;
        }

        // signal
        if (context->signal.signum != 0) {
            storage->signalSet = 1;
            storage->signalCode = context->signal.sigcode;
            storage->signalNumber = context->signal.signum;
        }

#define IS_TYPE(type) (strncmp(type, context->monitorId, strlen(type)) == 0)

        if IS_TYPE ("NSException") {
            storage->exceptionSet = 1;
            storage->exceptionType = 0;
            strncpy(storage->exceptionName, context->NSException.name, EMB_SMALL_BUFFER_SIZE - 1);
            if (context->NSException.userInfo) {
                strncpy(storage->exceptionUserInfo, context->NSException.userInfo, EMB_LARGE_BUFFER_SIZE - 1);
            }

        } else if IS_TYPE ("CPPException") {
            storage->exceptionSet = 1;
            storage->exceptionType = 1;
            strncpy(storage->exceptionName, context->CPPException.name, EMB_SMALL_BUFFER_SIZE - 1);
        }
    });
}

void EMBTerminationStorageUpdate(BOOL canLock, EMBTerminationStorageUpdateBlock _Nullable block)
{
    if (canLock) {
        os_unfair_lock_lock(&sStorageLock);
    }

    sStorage->updateTimestampMonotonicMillis = monotonic();
    if (block) {
        block(sStorage);
    }

    if (canLock) {
        os_unfair_lock_unlock(&sStorageLock);
    }
}

BOOL EMBTerminationStorageRemoveForIdentifier(NSString *_Nonnull identifier)
{
    if (!identifier) {
        return NO;
    }
    NSURL *appStorageURL = [[rootURL() URLByAppendingPathComponent:identifier]
        URLByAppendingPathExtension:kEMBTerminationStorageExtension];
    return [NSFileManager.defaultManager removeItemAtURL:appStorageURL error:nil];
}

NSArray<NSString *> *_Nonnull EMBTerminationStorageGetIdentifiers(void)
{
    return fileWithExtensionInURL(rootURL(), kEMBTerminationStorageExtension, NO);
}

BOOL EMBTerminationStorageForIdentifier(NSString *_Nonnull identifier, EMBTerminationStorage *_Nonnull outStorage)
{
    if (!outStorage || !identifier) {
        return NO;
    }
    NSURL *appStorageURL = [[rootURL() URLByAppendingPathComponent:identifier]
        URLByAppendingPathExtension:kEMBTerminationStorageExtension];
    return EMBTerminationStorageLoad(appStorageURL, outStorage);
}

// Call this early, but not before any type of system that might measure startup.
__attribute__((constructor(103))) static void EMBTerminationStorageInit(void)
{
    @autoreleasepool {
        EMBTerminationStorageInitialize();
    }
}

