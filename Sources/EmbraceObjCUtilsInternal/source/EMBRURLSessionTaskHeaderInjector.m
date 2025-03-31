//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
    

#import "EMBRURLSessionTaskHeaderInjector.h"

@implementation EMBRURLSessionTaskHeaderInjector

+ (BOOL)injectHeaderWithKey:(NSString *)key
                      value:(NSString *)value
                    intoTask:(NSURLSessionTask *)task
{
    if (key == nil || value == nil || task == nil) {
        return NO;
    }

    BOOL didInjectHeader = NO;

    if ([task respondsToSelector:@selector(originalRequest)]) {
        NSURLRequest *originalRequest = task.originalRequest;
        if (originalRequest != nil &&
            [originalRequest isKindOfClass:[NSMutableURLRequest class]]) {
            NSMutableURLRequest *mutableOriginal = (NSMutableURLRequest *)originalRequest;
            [mutableOriginal setValue:value forHTTPHeaderField:key];
            didInjectHeader = YES;
        }
    }

    if ([task respondsToSelector:@selector(currentRequest)]) {
        NSURLRequest *currentRequest = task.currentRequest;
        if (currentRequest != nil &&
            [currentRequest isKindOfClass:[NSMutableURLRequest class]]) {
            NSMutableURLRequest *mutableCurrent = (NSMutableURLRequest *)currentRequest;
            [mutableCurrent setValue:value forHTTPHeaderField:key];
            didInjectHeader = YES;
        }
    }

    return didInjectHeader;
}

@end
