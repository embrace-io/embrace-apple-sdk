//
//  AppDelegate.m
//  DemoObjectiveC
//
//  Created by Jonathon Copeland on 10/19/23.
//
@import EmbraceCore;

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    EMBEndpoints* endpoint = [[EMBEndpoints alloc] init];
    
    EMBOptions* options = [[EMBOptions alloc] initWithAppId:@"" appGroupId:nil platform:EMBPlatformIOS endpoints:endpoint collectors:@[[AppInfoCollector new], [DeviceInfoCollector new]]];
    NSError* error = nil;
    
    [Embrace setupWithOptions:options error:&error];
    if(error != nil){
        NSLog(@"Failed to setup embrace %@", error.localizedDescription);
        return NO;
    }
    
    [[Embrace client] startAndReturnError:&error];
    if(error != nil){
        NSLog(@"Failed to start embrace %@", error.localizedDescription);
        return NO;
    }
    
    return YES;
}


#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}


@end
