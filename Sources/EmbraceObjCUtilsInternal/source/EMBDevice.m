//
//  EMBDevice.m
//  Embrace
//
//  Created by Brian Wagner on 9/13/16.
//  Copyright © 2016 embrace.io. All rights reserved.
//

#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/ldsyms.h>
#import <sys/sysctl.h>
#import "EMBDevice.h"

#if __has_include(<WatchKit/WatchKit.h>)
#define WATCHKIT_AVAILABLE 1
#import <WatchKit/WatchKit.h>
#endif

#if __has_include(<UIKit/UIKit.h>)
#define UIKIT_AVAILABLE 1
#import <UIKit/UIKit.h>
#endif

#if __has_include(<AppKit/AppKit.h>)
#define APPKIT_AVAILABLE 1
#include <AppKit/AppKit.h>
#endif

#if __has_include(<CoreTelephony/CTTelephonyNetworkInfo.h>)
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#endif

NSString *const EMBAppEnvironmentDevelopmentValue = @"dev";
NSString *const EMBAppEnvironmentProductionValue = @"prod";
NSString *const EMBAppEnvironmentDetailSimulatorValue = @"si";
NSString *const EMBAppEnvironmentDetailDevelopmentValue = @"de";
NSString *const EMBAppEnvironmentDetailAdHocValue = @"ad";
NSString *const EMBAppEnvironmentDetailEnterpriseValue = @"en";
NSString *const EMBAppEnvironmentDetailTestFlightValue = @"te";
NSString *const EMBAppEnvironmentDetailAppStoreValue = @"ap";

NSString *const EMBEnvUnknownDueToErrorGettingBinaryValue = @"u1";
NSString *const EMBEnvUnknownDueToErrorScanningBinaryValue = @"u2";
NSString *const EMBEnvUnknownDueToErrorParsingPlistValue = @"u3";
NSString *const EMBEnvUnknownMissingInfoValue = @"u4";

NSString *const signerIdentityString = @"signeridentity";

typedef NS_ENUM(NSInteger, EMBReleaseMode) {
    EMBReleaseUnknownDueToErrorGettingBinary,
    EMBReleaseUnknownDueToErrorScanningBinary,
    EMBReleaseUnknownDueToErrorParsingPlist,
    EMBReleaseUnknownDueToMissingInfo,
    EMBReleaseSimulator,
    EMBReleaseDevelopment,
    EMBReleaseAdHoc,
    EMBReleaseEnterprise,
    EMBReleaseTestFlight,
    EMBReleaseAppStore
};

@implementation EMBDevice

#pragma mark - Accessors

+ (NSString *)appVersion
{
    NSString* _appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    // Just in case folks get too creative with version numbers we're trimming the start/end of spaces, newlines, etc.
    _appVersion = [_appVersion stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return _appVersion;
}

+ (NSString *)environment
{
    NSString *env;
    EMBReleaseMode mode = [self getReleaseMode];
    
    switch (mode) {
        case EMBReleaseEnterprise:
        case EMBReleaseAppStore:
            env = EMBAppEnvironmentProductionValue;
            break;
        default:
            env = EMBAppEnvironmentDevelopmentValue;
            break;
    }
    
    return env;
}

+ (NSString *)environmentDetail
{
    NSString *env;
    EMBReleaseMode mode = [self getReleaseMode];
    
    switch (mode) {
        case EMBReleaseUnknownDueToErrorGettingBinary:
            env = EMBEnvUnknownDueToErrorGettingBinaryValue;
            break;
        case EMBReleaseUnknownDueToErrorScanningBinary:
            env = EMBEnvUnknownDueToErrorScanningBinaryValue;
            break;
        case EMBReleaseUnknownDueToErrorParsingPlist:
            env = EMBEnvUnknownDueToErrorParsingPlistValue;
            break;
        case EMBReleaseUnknownDueToMissingInfo:
            env = EMBEnvUnknownMissingInfoValue;
            break;
        case EMBReleaseSimulator:
            env = EMBAppEnvironmentDetailSimulatorValue;
            break;
        case EMBReleaseDevelopment:
            env = EMBAppEnvironmentDetailDevelopmentValue;
            break;
        case EMBReleaseAdHoc:
            env = EMBAppEnvironmentDetailAdHocValue;
            break;
        case EMBReleaseEnterprise:
            env = EMBAppEnvironmentDetailEnterpriseValue;
            break;
        case EMBReleaseTestFlight:
            env = EMBAppEnvironmentDetailTestFlightValue;
            break;
        case EMBReleaseAppStore:
            env = EMBAppEnvironmentDetailAppStoreValue;
            break;
        default:
            break;
    }
    
    return env;
}

+ (NSString *)bundleVersion
{
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] ?: @"";
}

+ (NSUUID *)buildUUID
{
    const struct mach_header *machHeader = NULL;
    
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; ++i) {
        const struct mach_header *header = _dyld_get_image_header(i);
        if (header == NULL) {
            continue;
        }
        
        if (header->filetype == MH_EXECUTE) {
            machHeader = header;
            break;
        }
    }
    
    if (machHeader == NULL) {
        return nil;
    }
    
    BOOL is64bit = machHeader->magic == MH_MAGIC_64 || machHeader->magic == MH_CIGAM_64;
    uintptr_t cursor = (uintptr_t)machHeader + (is64bit ? sizeof(struct mach_header_64) : sizeof(struct mach_header));
    const struct segment_command *segmentCommand = NULL;
    for (uint32_t i = 0; i < machHeader->ncmds; ++i, cursor += segmentCommand->cmdsize) {
        segmentCommand = (struct segment_command *)cursor;
        
        if (segmentCommand->cmd == LC_UUID) {
            const struct uuid_command *uuidCommand = (const struct uuid_command *)segmentCommand;
            return [[NSUUID alloc] initWithUUIDBytes:uuidCommand->uuid];
        }
    }
    return nil;
}

+ (NSString *)manufacturer
{
    return @"Apple";
}

+ (NSString *)model
{
    NSString* _model = NULL;
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *name = malloc(size);
    sysctlbyname("hw.machine", name, &size, NULL, 0);
    _model = [NSString stringWithUTF8String:name];
    free(name);
    
    if (!_model) {
        _model = @"Not available.";
    }
    
    return _model;
}

+ (NSString *)architecture
{
    NSMutableString *cpu = [[NSMutableString alloc] init];
    size_t size;
    cpu_type_t type;
    cpu_subtype_t subtype;
    size = sizeof(type);
    sysctlbyname("hw.cputype", &type, &size, NULL, 0);
    
    size = sizeof(subtype);
    sysctlbyname("hw.cpusubtype", &subtype, &size, NULL, 0);
    
    // values for cputype and cpusubtype are defined in mach/machine.h
    if (type == CPU_TYPE_X86) {
        [cpu appendString:@"x86"];
    }
    else if (type == CPU_TYPE_ARM) {
        [cpu appendString:@"arm"];
        
        switch(subtype) {
            case CPU_SUBTYPE_ARM_V7:
                [cpu appendString:@"v7"];
                break;
                
            case CPU_SUBTYPE_ARM_V7S:
                [cpu appendString:@"v7s"];
                break;
            default:
                break;
        }
    }
    else if (type == CPU_TYPE_ARM64) {
        [cpu appendString:@"arm64"];
        
        switch(subtype) {
            case CPU_SUBTYPE_ARM64E:
                [cpu appendString:@"e"];
                break;
            default:
                break;
        }
    }
    else {
        [cpu appendString:@"unknown"];
    }
    
    return cpu;
}

+ (BOOL)isJailbroken
{
    BOOL jailbroken = false;
    
#if !TARGET_OS_SIMULATOR && UIKIT_AVAILABLE
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath;
    NSString *signerIdentityKey = nil;
    NSDictionary *bundleInfoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSEnumerator *infoEnumerator = [bundleInfoDictionary keyEnumerator];
    NSString *key;
    
    while ((key = [infoEnumerator nextObject])) {
        if ([[key lowercaseString] isEqualToString:signerIdentityString]) {
            signerIdentityKey = [key copy];
            break;
        }
    }
    
    jailbroken = signerIdentityKey != nil;
    
    if (!jailbroken) {
        NSArray *filePaths = @[@"/usr/sbin/sshd",
                               @"/Library/MobileSubstrate/MobileSubstrate.dylib",
                               @"/bin/bash",
                               @"/usr/libexec/sftp-server",
                               @"/Applications/Cydia.app",
                               @"/Applications/blackra1n.app",
                               @"/Applications/FakeCarrier.app",
                               @"/Applications/Icy.app",
                               @"/Applications/IntelliScreen.app",
                               @"/Applications/MxTube.app",
                               @"/Applications/RockApp.app",
                               @"/Applications/SBSettings.app",
                               @"/Applications/WinterBoard.app",
                               @"/Library/MobileSubstrate/DynamicLibraries/LiveClock.plist",
                               @"/Library/MobileSubstrate/DynamicLibraries/Veency.plist",
                               @"/private/var/lib/apt",
                               @"/private/var/lib/cydia",
                               @"/private/var/mobile/Library/SBSettings/Themes",
                               @"/private/var/stash",
                               @"/private/var/tmp/cydia.log",
                               @"/System/Library/LaunchDaemons/com.ikey.bbot.plist",
                               @"/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist"];
        
        for (filePath in filePaths) {
            jailbroken = [fileManager fileExistsAtPath:filePath];
            
            if (jailbroken) {
                break;
            }
        }
    }
    
    if (!jailbroken) {
        // Valid test only if running as root on a jailbroken device
        NSData *jailbrokenTestData = [@"Jailbroken filesystem test." dataUsingEncoding:NSUTF8StringEncoding];
        filePath = @"/private/embjailbrokentest.txt";
        jailbroken = [jailbrokenTestData writeToFile:filePath atomically:NO];
        
        if (jailbroken) {
            [fileManager removeItemAtPath:filePath error:nil];
        }
    }
#endif
    
    return jailbroken;
    
}

+ (NSString *)locale
{
    return [[NSLocale currentLocale] localeIdentifier] ?: @"";
}

//TotalDiskSpace
+ (NSNumber *)totalDiskSpace
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDictionary *fileSystemAttributes = [fileManager attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
    return fileSystemAttributes[NSFileSystemSize] ?: @(-1);
}

+ (NSString *)operatingSystemType
{
#if WATCHKIT_AVAILABLE
    return [WKInterfaceDevice currentDevice].systemName;
#elif UIKIT_AVAILABLE
    return [UIDevice currentDevice].systemName;
#else
    return  @"macOS";
#endif
}

+ (NSString *)operatingSystemVersion
{
    NSOperatingSystemVersion operatingSystemVersion = [NSProcessInfo processInfo].operatingSystemVersion;
    if (operatingSystemVersion.patchVersion == 0) {
        return [NSString stringWithFormat: @"%i.%i", (int)operatingSystemVersion.majorVersion, (int)operatingSystemVersion.minorVersion];
    } else {
        return [NSString stringWithFormat: @"%i.%i.%i", (int)operatingSystemVersion.majorVersion, (int)operatingSystemVersion.minorVersion, (int)operatingSystemVersion.patchVersion];
    }
}

+ (NSString *)operatingSystemBuild
{
    int cmd[2] = { CTL_KERN, KERN_OSVERSION };
    size_t s = 0;
    sysctl(cmd, sizeof(cmd) / sizeof(cmd[0]), NULL, &s, NULL, 0);
    char b[s];
    
    if (sysctl(cmd, sizeof(cmd) / sizeof(cmd[0]), b, &s, NULL, 0) != -1) {
        return [NSString stringWithCString:b encoding:[NSString defaultCStringEncoding]];
    } else {
        return @"";
    }
}

+ (NSString *)timezoneDescription
{
    return [[[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierISO8601] timeZone] name] ?: @"";
}

+ (EMBReleaseMode)getReleaseMode
{
#if TARGET_IPHONE_SIMULATOR
    return EMBReleaseSimulator;
#else
    // There is no provisioning profile in AppStore Apps
    NSString *provisioningPath = [[NSBundle mainBundle] pathForResource:@"embedded" ofType:@"mobileprovision"];
    
    // If there is no provisioningPath, this must be an app store or TF release
    if (!provisioningPath) {
        NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
        if ([[receiptURL lastPathComponent] isEqualToString:@"sandboxReceipt"]) {
            // If an application installed through TestFlight the receipt file is named StoreKit\sandboxReceipt
            return EMBReleaseTestFlight;
        } else {
            return EMBReleaseAppStore;
        }
    }
    
    // NSISOLatin1 keeps the binary wrapper from being parsed as unicode and dropped as invalid
    NSError *binaryError;
    NSString *binaryString = [NSString stringWithContentsOfFile:provisioningPath encoding:NSISOLatin1StringEncoding error:&binaryError];
    
    if (!binaryString || binaryError) {
        return EMBReleaseUnknownDueToErrorGettingBinary;
    }
    
    NSString *plistString;
    NSScanner *scanner = [NSScanner scannerWithString:binaryString];
    BOOL beginFound = [scanner scanUpToString:@"<plist" intoString:nil];
    BOOL endFound = [scanner scanUpToString:@"</plist>" intoString:&plistString];
    plistString = [NSString stringWithFormat:@"%@</plist>", plistString];
    
    if (!beginFound || !endFound) {
        return EMBReleaseUnknownDueToErrorScanningBinary;
    }
    
    NSData *plistDataLatin1 = [plistString dataUsingEncoding:NSISOLatin1StringEncoding];
    NSError *plistError;
    NSDictionary *mobileProvision = [NSPropertyListSerialization propertyListWithData:plistDataLatin1 options:NSPropertyListImmutable format:NULL error:&plistError];
    
    if (!mobileProvision || plistError) {
        return EMBReleaseUnknownDueToErrorParsingPlist;
    }
    
    if ([[mobileProvision objectForKey:@"ProvisionsAllDevices"] boolValue]) {
        // enterprise distribution contains ProvisionsAllDevices - true
        return EMBReleaseEnterprise;
    } else if ([mobileProvision objectForKey:@"ProvisionedDevices"] && [[mobileProvision objectForKey:@"ProvisionedDevices"] count] > 0) {
        NSDictionary *entitlements = [mobileProvision objectForKey:@"Entitlements"];
        if ([[entitlements objectForKey:@"get-task-allow"] boolValue]) {
            // development contains UDIDs and get-task-allow is true
            return EMBReleaseDevelopment;
        } else {
            // ad hoc contains UDIDs and get-task-allow is false
            return EMBReleaseAdHoc;
        }
    } else {
        return EMBReleaseUnknownDueToMissingInfo;
    }
    
#endif
}

// see: https://developer.apple.com/library/content/qa/qa1361/_index.html
// Returns true if the current process is being debugged (either
// running under the debugger or has a debugger attached post facto).
+ (BOOL)isDebuggerAttached
{
    int                 junk;
    int                 mib[4];
    struct kinfo_proc   info;
    size_t              size;

    // Initialize the flags so that, if sysctl fails for some bizarre
    // reason, we get a predictable result.

    info.kp_proc.p_flag = 0;

    // Initialize mib, which tells sysctl the info we want, in this case
    // we're looking for information about a specific process ID.

    mib[0] = CTL_KERN;
    mib[1] = KERN_PROC;
    mib[2] = KERN_PROC_PID;
    mib[3] = getpid();

    // Call sysctl.

    size = sizeof(info);
    junk = sysctl(mib, sizeof(mib) / sizeof(*mib), &info, &size, NULL, 0);
    assert(junk == 0);

    // We're being debugged if the P_TRACED flag is set.

    return ( (info.kp_proc.p_flag & P_TRACED) != 0 );
}

@end
