//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
    

#import "NSURLSessionTask+Embrace.h"

@implementation NSURLSessionTask (Embrace)

- (BOOL)injectHeaderWithKey:(NSString *)key value:(NSString *)value {
    if (key == nil || value == nil) {
        return NO;
    }

    if (![self.originalRequest isKindOfClass:[NSMutableURLRequest class]]) {
        return NO;
    }

    NSMutableURLRequest *request = (NSMutableURLRequest *)self.originalRequest;
    [request setValue:value forHTTPHeaderField:key];

    return YES;
}

@end
