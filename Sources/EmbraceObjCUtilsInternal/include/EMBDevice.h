//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EMBDevice : NSObject

- (instancetype)init NS_UNAVAILABLE;

@property (class, nullable, readonly)  NSString *appVersion;
@property (class, nullable, readonly)  NSUUID *buildUUID;

@property (class, readonly)  NSString *environment;
@property (class, readonly)  NSString *environmentDetail;
@property (class, readonly)  NSString *bundleVersion;
@property (class, readonly)  NSString *manufacturer;
@property (class, readonly)  NSString *model;
@property (class, readonly)  NSString *architecture;
@property (class, readonly)  NSString *locale;

@property (class, readonly)  NSString *operatingSystemType;
@property (class, readonly)  NSString *operatingSystemVersion;
@property (class, readonly)  NSString *operatingSystemBuild;
@property (class, readonly)  NSString *timezoneDescription;

@property (class, readonly)  NSNumber *totalDiskSpace;

@property (class, readonly)  BOOL isJailbroken;
@property (class, readonly)  BOOL isDebuggerAttached;

@end

NS_ASSUME_NONNULL_END
