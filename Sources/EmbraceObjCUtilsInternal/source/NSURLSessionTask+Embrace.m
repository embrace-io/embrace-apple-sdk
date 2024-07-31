//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
    

#import "NSURLSessionTask+Embrace.h"

@implementation NSURLSessionTask (Embrace)

- (BOOL)injectHeaderWithKey:(NSString *)key value:(NSString *)value {
    if (key == nil || value == nil) {
        return NO;
    }

    if (![self.originalRequest isKindOfClass:[NSMutableURLRequest class]] ||
        ![self.currentRequest isKindOfClass:[NSMutableURLRequest class]]) {
        return NO;
    }

    NSMutableURLRequest *request = (NSMutableURLRequest *)self.originalRequest;
    [request setValue:value forHTTPHeaderField:key];

    NSMutableURLRequest *currentRequest = (NSMutableURLRequest *)self.currentRequest;
    [currentRequest setValue:value forHTTPHeaderField:key];

    return YES;
}

@end
