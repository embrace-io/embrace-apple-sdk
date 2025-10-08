//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#import "URLSessionDelegateImplementerButWithoutConforming.h"

@implementation URLSessionDelegateImplementerButWithoutConforming

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    self.didInvokeDidReceiveData = YES;
}

- (void)URLSession:(nonnull NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error
{
    self.didInvokeDidBecomeInvalidWithError = YES;
}

- (void)URLSession:(NSURLSession *)session
                          task:(NSURLSessionTask *)task
    didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics
{
    self.didInvokeDidFinishCollectingMetrics = YES;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error
{
    self.didInvokedDidCompleteWithError = YES;
}

@end
