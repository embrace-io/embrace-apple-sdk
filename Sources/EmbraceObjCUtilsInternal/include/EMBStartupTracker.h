//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EMBStartupTracker : NSObject

@property(nonatomic, strong) NSDate *loadTime;
@property(nonatomic, strong) NSDate *constructorMostFarFromMainTime;
@property(nonatomic, strong) NSDate *constructorClosestToMainTime;

@property(nonatomic, strong, nullable) NSDate *firstFrameTime;
@property(nonatomic, copy, nullable) void (^onFirstFrameTimeSet)(NSDate *);

@property(nonatomic, strong, nullable) NSDate *appDidFinishLaunchingEndTime;
@property(nonatomic, copy, nullable) void (^onAppDidFinishLaunchingEndTimeSet)(NSDate *);

@property(nonatomic, strong, nullable) NSDate *appFirstDidBecomeActiveTime;

@property(nonatomic, strong, nullable) NSDate *sdkSetupStartTime;
@property(nonatomic, strong, nullable) NSDate *sdkSetupEndTime;
@property(nonatomic, strong, nullable) NSDate *sdkStartStartTime;
@property(nonatomic, strong, nullable) NSDate *sdkStartEndTime;

+ (instancetype)shared;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (void)resetLifecycleNotifications;

@end

NS_ASSUME_NONNULL_END
