//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
    

#import "EMBRURLSessionTaskHeaderInjector.h"

@implementation EMBRURLSessionTaskHeaderInjector

+ (BOOL)injectHeaderWithKey:(NSString *)key
                      value:(NSString *)value
                    intoTask:(NSURLSessionTask *)task
{
    if (key == nil || value == nil) {
        return NO;
    }

    if (![task.originalRequest isKindOfClass:[NSMutableURLRequest class]] ||
        ![task.currentRequest isKindOfClass:[NSMutableURLRequest class]]) {
        return NO;
    }

    NSMutableURLRequest *originalRequest = (NSMutableURLRequest *)task.originalRequest;
    [originalRequest setValue:value forHTTPHeaderField:key];

    NSMutableURLRequest *currentRequest = (NSMutableURLRequest *)task.currentRequest;
    [currentRequest setValue:value forHTTPHeaderField:key];

    return YES;
}

@end
