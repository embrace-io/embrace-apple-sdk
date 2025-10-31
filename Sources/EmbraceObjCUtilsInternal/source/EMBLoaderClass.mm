//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>
#import <pthread.h>
#import <sys/time.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#else
#import <UIKit/UIKit.h>
#endif

#import "EMBDisplayLinkProxy.h"
#import "EMBLoaderClass.h"
#import "EMBStartupTracker.h"

static pthread_t sMainThread = NULL;
pthread_t EmbraceGetMainThread(void) { return sMainThread; }

NSError *_Nullable EmbraceSaveManagedContext(NSManagedObjectContext *context)
{
    NSError *error = nil;
    @try {
        if (![context save:&error]) {
            return error;
        }
    } @catch (NSException *exception) {
        NSMutableDictionary *info = exception.userInfo ? [exception.userInfo mutableCopy] : [NSMutableDictionary new];
        info[@"exception_name"] = exception.name;
        info[@"exception_reason"] = exception.reason;
        return [NSError errorWithDomain:@"EmbraceSaveManagedContextException" code:0 userInfo:info];
    }
    return nil;
}

@implementation EMBLoaderClass

#pragma mark -  Start up measurement

// First method to be called
+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sMainThread = pthread_self();
    });
    [[EMBStartupTracker shared] setLoadTime:[NSDate now]];
}

// Second to be called
__attribute__((constructor(101))) static void calledAsEarlyAsPossible(void)
{
    [[EMBStartupTracker shared] setConstructorMostFarFromMainTime:[NSDate now]];
}

// Third to be called
// Will be called right before main() is called.
__attribute__((constructor(65535))) static void calledRightBeforeMain(void)
{
    [[EMBStartupTracker shared] setConstructorClosestToMainTime:[NSDate now]];
}

@end

