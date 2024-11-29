//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
    

#import "EMBURLSessionDelegateForwarder.h"

@implementation EMBURLSessionDelegateForwarder

#pragma mark - Forwarding of NSURLSessionDelegate methods

- (void)forwardToObject:(NSObject *)object
             URLSession:(nonnull NSURLSession *)session
didBecomeInvalidWithError:(nullable NSError *)error {
    id<NSURLSessionDelegate> sessionDelegate = (id<NSURLSessionDelegate>)object;
    [sessionDelegate URLSession:session didBecomeInvalidWithError:error];
}

#pragma mark - Forwarding of NSURLSessionDataDelegate methods

- (void)forwardToObject:(NSObject *)object
             URLSession:(nonnull NSURLSession *)session
               dataTask:(nonnull NSURLSessionDataTask *)task
         didReceiveData:(nonnull NSData *)data {
    id<NSURLSessionDataDelegate> dataDelegate = (id<NSURLSessionDataDelegate>)object;
    [dataDelegate URLSession:session dataTask:task didReceiveData:data];
}

#pragma mark - Forwarding of NSURLSessionTaskDelegate methods

- (void)forwardToObject:(NSObject *)object
             URLSession:(nonnull NSURLSession *)session
                   task:(nonnull NSURLSessionTask *)task
didFinishCollectiongMetrics:(nonnull NSURLSessionTaskMetrics *)metrics{
    id<NSURLSessionTaskDelegate> taskDelegate = (id<NSURLSessionTaskDelegate>)object;
    [taskDelegate URLSession:session task:task didFinishCollectingMetrics:metrics];
}

- (void)forwardToObject:(NSObject *)object
             URLSession:(nonnull NSURLSession *)session
                   task:(nonnull NSURLSessionTask *)task
   didCompleteWithError:(nullable NSError *)error {
    id<NSURLSessionTaskDelegate> taskDelegate = (id<NSURLSessionTaskDelegate>)object;
    [taskDelegate URLSession:session task:task didCompleteWithError:error];
}

#pragma mark - Forwarding of NSURLSessionDownloadDelegate methods

- (void)forwardToObject:(NSObject *)object
             URLSession:(nonnull NSURLSession *)session
           downloadTask:(nonnull NSURLSessionDownloadTask *)task
didFinishDownloadingToURL:(nonnull NSURL *)url {
    id<NSURLSessionDownloadDelegate> downloadDelegate = (id<NSURLSessionDownloadDelegate>)object;
    [downloadDelegate URLSession:session downloadTask:task didFinishDownloadingToURL:url];
}

@end
