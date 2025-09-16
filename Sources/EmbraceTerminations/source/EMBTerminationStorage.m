//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

/**
 * EMBTerminationStorage
 * ---------------------
 * Purpose:
 *   Persist lightweight termination/crash context for the current process to a
 *   memory-mapped file so that the next launch can reason about the previous
 *   session (e.g., whether it exited cleanly or crashed, and with what details).
 *
 * Storage format:
 *   The file contains a single, POD C struct (EMBTerminationStorage) written
 *   directly via mmap(2). The struct begins with a magic and version for
 *   validation, followed by timestamps (epoch and monotonic), process identity
 *   (pid and UUID), exit/crash markers, exception/mach/signal details, app
 *   transition state, and coarse memory state.
 *
 * File lifecycle:
 *   - On launch, we create a new file named by the current process identifier
 *     (UUID) under Application Support (or Caches on tvOS) in:
 *       <root>/embrace.io/termination/<uuid>.term
 *   - We memory-map the file and zero it; then we populate header fields.
 *   - Throughout the process lifetime we update the mapped struct in-place.
 *   - On library unload/process exit we call msync() as a best-effort flush.
 *   - On next launch we read the most recent .term file to present prior state.
 *
 * Concurrency & safety:
 *   - Updates outside crash-time use an os_unfair_lock for mutual exclusion.
 *   - Crash-time updates may run in async-signal contexts; in those cases we
 *     avoid locking and only perform simple, async-safe writes.
 *   - Callers must pass canLock=NO when in async-signal-sensitive paths.
 *
 * Validation:
 *   - When loading a previous file, we validate magic, version, timestamps,
 *     pid and UUID, and we clamp string buffers to ensure NUL-termination.
 *
 * Non-goals:
 *   - This is not a crash report store. It is a minimal breadcrumb for the
 *     next launch to understand termination conditions.
 */

#import "EMBTerminationStorage.h"

#import <os/lock.h>
#import <stdlib.h>
#import <sys/mman.h>
#import <sys/stat.h>

@import EmbraceCommonInternal;
@import KSCrashRecording;

#pragma mark - Constants
// Constants for on-disk format and file naming

const uint64_t kEMBTerminationStorageVersion_1 = 1;
const uint64_t kEMBTerminationStorageCurrentVersion = kEMBTerminationStorageVersion_1;
const uint64_t kEMBTerminationStorageMagic = 0x45435241424D5245ULL;

NSString *const kEMBTerminationStorageExtension = @"term";

#pragma mark - Globals & State
// Process-wide state for the mapped storage and synchronization

static os_unfair_lock sStorageLock = OS_UNFAIR_LOCK_INIT;
static EMBTerminationStorage *sStorage = NULL;
static size_t sStorageSize = 0;

/// Returns the current time for the given clock in milliseconds.
static inline uint64_t milliseconds(clockid_t clock) { return clock_gettime_nsec_np(clock) / 1000000; }

/// Wall-clock time in milliseconds since Unix epoch.
static inline uint64_t walltime() { return milliseconds(CLOCK_REALTIME); }

/// Monotonic time in milliseconds (CLOCK_MONOTONIC_RAW).
static inline uint64_t monotonic() { return milliseconds(CLOCK_MONOTONIC_RAW); }

#pragma mark - Exit Hooks
// Clean-exit signals from atexit() and app termination

/// atexit() handler: marks a clean exit and that exit() was called.
static void _atExit(void)
{
    EMBTerminationStorageUpdate(YES, ^(EMBTerminationStorage *_Nonnull storage) {
        storage->cleanExitSet = 1;
        storage->exitCalled = 1;
    });
}

/// Notification callback for UIApplicationWillTerminateNotification; marks a clean exit and that terminate was called.
static void _willTerminateNotification(CFNotificationCenterRef center, void *observer, CFNotificationName name,
                                       const void *object, CFDictionaryRef userInfo)
{
    EMBTerminationStorageUpdate(YES, ^(EMBTerminationStorage *_Nonnull storage) {
        storage->cleanExitSet = 1;
        storage->terminateCalled = 1;
    });
}

#pragma mark - Private Helpers
// Filesystem utilities, mapping, validation, and logging

/**
 * Returns the root directory URL for termination files, creating it if necessary.
 * On tvOS uses NSCachesDirectory; otherwise NSApplicationSupportDirectory.
 * Path: <container>/<embrace.io>/termination
 */
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

/// Returns an array of filenames (optionally stripped of extension) with the given extension in directoryURL.
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

/**
 * Returns the most recently modified file URL with the given extension in directoryURL.
 * Returns nil if no such file exists or on error.
 */
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

/**
 * Loads the EMBTerminationStorage struct from a file URL.
 * Validates magic, version, timestamps, pid, UUID, and clamps strings.
 * Returns YES on successful load and validation, NO otherwise.
 */
static bool EMBTerminationStorageLoad(NSURL *url, EMBTerminationStorage *storage)
{
    const char *path = url.path.UTF8String;

    int fd = open(path, O_RDONLY);
    if (fd == -1) {
        printf("Could not open file %s: %s\n", path, strerror(errno));
        return false;
    }

    // Verify file size is at least the size of EMBTerminationStorage
    struct stat st = { 0 };
    if (fstat(fd, &st) == -1) {
        printf("Could not stat file %s: %s\n", path, strerror(errno));
        close(fd);
        return false;
    }
    size_t expectedSize = sizeof(EMBTerminationStorage);
    if ((size_t)st.st_size < expectedSize) {
        printf("File %s too small: %lld bytes, expected at least %zu\n", path, (long long)st.st_size, expectedSize);
        close(fd);
        return false;
    }

    // Read exactly the struct size from the beginning
    ssize_t nread = pread(fd, storage, expectedSize, 0);
    if (nread < 0) {
        printf("Could not read file %s: %s\n", path, strerror(errno));
        close(fd);
        return false;
    }
    if ((size_t)nread != expectedSize) {
        printf("Short read on %s: %zd bytes, expected %zu\n", path, nread, expectedSize);
        close(fd);
        return false;
    }

    close(fd);

    // Basic header validation
    if (storage->magic != kEMBTerminationStorageMagic) {
        printf("Wrong magic in %s\n", path);
        return false;
    }

    if (storage->version != kEMBTerminationStorageVersion_1) {
        printf("Wrong version in %s: %llu\n", path, (unsigned long long)storage->version);
        return false;
    }

    // Sanity checks on timestamps
    if (storage->creationTimestampEpochMillis == 0 || storage->creationTimestampMonotonicMillis == 0 ||
        storage->updateTimestampMonotonicMillis == 0) {
        printf("Invalid timestamps in %s (zero values)\n", path);
        return false;
    }
    if (storage->updateTimestampMonotonicMillis < storage->creationTimestampMonotonicMillis) {
        printf("Update timestamp earlier than creation in %s\n", path);
        return false;
    }

    // PID must be valid
    if (storage->pid <= 0) {
        printf("Invalid pid in %s: %d\n", path, storage->pid);
        return false;
    }

    // UUID should not be all zeros
    {
        uuid_t zero = { 0 };
        if (memcmp(storage->uuid, zero, sizeof(uuid_t)) == 0) {
            printf("Invalid uuid (all zeros) in %s\n", path);
            return false;
        }
    }

    // App transition state should be within known enum bounds (defensive)
    if (storage->appTransitionState < 0 || storage->appTransitionState > KSCrashAppTransitionStateBackground) {
        // If enum grows, this is a soft warning; treat as invalid only if wildly out of range
        printf("Suspicious appTransitionState in %s: %d\n", path, storage->appTransitionState);
        // Do not fail hard here; comment out the return if being too strict causes issues
        // return false;
    }

    // Ensure string buffers are NUL-terminated within their bounds
    storage->exceptionName[EMB_SMALL_BUFFER_SIZE - 1] = '\0';
    storage->exceptionReason[EMB_LARGE_BUFFER_SIZE - 1] = '\0';
    storage->exceptionUserInfo[EMB_LARGE_BUFFER_SIZE - 1] = '\0';

    // Memory values can be zero, but if limit is set, footprint should be <= limit
    if (storage->memoryLimit > 0 && storage->memoryFootprint > storage->memoryLimit) {
        printf("Suspicious memory footprint in %s: footprint=%lld limit=%lld\n", path,
               (long long)storage->memoryFootprint, (long long)storage->memoryLimit);
        // Not a hard failure; could be transient
    }

    return true;
}

/**
 * Creates or truncates a file to the given size and memory maps it with read-write.
 * Returns a pointer to the mapped memory or NULL on failure.
 * The returned pointer is asserted to be aligned to EMBTerminationStorage alignment.
 * On failure, the file is unlinked and cleaned up.
 */
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

/// Logs the contents of an EMBTerminationStorage struct to stdout.
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

#pragma mark - Public API
// Initialization, updates, and query helpers

static BOOL EMBTerminationStorageInitialize()
{
    printf("size of storage: %lu\n", sizeof(EMBTerminationStorage));

    // Attempt to load and log the most recent previous session.
    NSURL *previousStorageURL = mostRecentFileWithExtensionInURL(rootURL(), kEMBTerminationStorageExtension);
    if (previousStorageURL) {
        EMBTerminationStorage storage = { 0 };
        if (EMBTerminationStorageLoad(previousStorageURL, &storage)) {
            printf("\n----- PREVIOUS SESSION -----\n");
            EMBTerminationStorageLog(&storage);
            printf("----- -------- ------- -----\n\n");
        }
    }

    // Create a fresh, zeroed, memory-mapped storage for this process.
    NSString *identifier = EMBCurrentProcessIdentifier.value;
    NSURL *appStorageURL = [[rootURL() URLByAppendingPathComponent:identifier]
        URLByAppendingPathExtension:kEMBTerminationStorageExtension];

    size_t size = sizeof(EMBTerminationStorage);
    void *mmapData = EMBTerminationStorageMap(appStorageURL, size);
    if (!mmapData) {
        return NO;
    }
    memset(mmapData, 0, size);

    // Record mapping pointer and size.
    sStorageSize = size;
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

/**
 * Captures fatal crash context into the termination storage.
 * Async-signal-aware: uses canLock flag to avoid locking when unsafe.
 */
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

    // Update everything, we can lock if we're not in an async safe callback.
    EMBTerminationStorageUpdate(plan->requiresAsyncSafety == NO, ^(EMBTerminationStorage *_Nonnull storage) {
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

#define IS_TYPE(type) (context->monitorId && strncmp(context->monitorId, type, strlen(type)) == 0)

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

/**
 * Updates the termination storage, optionally acquiring a lock if safe to do so.
 * Updates the monotonic timestamp before invoking the update block.
 */
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

/// Removes the termination storage file for the given identifier. Returns YES on success.
BOOL EMBTerminationStorageRemoveForIdentifier(NSString *_Nonnull identifier)
{
    if (!identifier) {
        return NO;
    }
    NSURL *appStorageURL = [[rootURL() URLByAppendingPathComponent:identifier]
        URLByAppendingPathExtension:kEMBTerminationStorageExtension];
    return [NSFileManager.defaultManager removeItemAtURL:appStorageURL error:nil];
}

/// Returns all identifiers (filenames without extension) of termination storage files.
NSArray<NSString *> *_Nonnull EMBTerminationStorageGetIdentifiers(void)
{
    return fileWithExtensionInURL(rootURL(), kEMBTerminationStorageExtension, NO);
}

/// Loads the termination storage contents for the given identifier into outStorage. Returns YES on success.
BOOL EMBTerminationStorageForIdentifier(NSString *_Nonnull identifier, EMBTerminationStorage *_Nonnull outStorage)
{
    if (!outStorage || !identifier) {
        return NO;
    }
    NSURL *appStorageURL = [[rootURL() URLByAppendingPathComponent:identifier]
        URLByAppendingPathExtension:kEMBTerminationStorageExtension];
    return EMBTerminationStorageLoad(appStorageURL, outStorage);
}

/// Early constructor to initialize termination storage at library load time.
__attribute__((constructor(103))) static void EMBTerminationStorageInit(void)
{
    @autoreleasepool {
        EMBTerminationStorageInitialize();
    }
}

/// Destructor to best-effort flush storage at library unload / process exit.
__attribute__((destructor)) static void EMBTerminationStorageDeinit(void)
{
    // Best-effort final flush and cleanup at library unload / process exit.
    if (sStorage && sStorageSize > 0) {
        // msync to try to flush mmap changes to disk before exit.
        msync((void *)sStorage, sStorageSize, MS_SYNC);
    }
}

