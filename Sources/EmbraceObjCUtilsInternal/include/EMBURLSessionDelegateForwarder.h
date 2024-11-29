//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
    

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A utility class for forwarding delegate method calls from a `NSURLSession` to a specific target object.
///
/// The `EMBURLSessionDelegateForwarder` class is designed to forward `NSURLSession` delegate method calls
/// to the appropriate target object while ensuring type safety. The forwarding mechanism casts the target
/// object to the specific `NSURLSession` delegate protocol (e.g., `NSURLSessionTaskDelegate`, `NSURLSessionDataDelegate`).
///
/// This class is commonly used when intercepting `NSURLSession` delegate calls in proxy scenarios and
/// redirecting them to a different object.
///
/// - Note: The target object must implement the appropriate `NSURLSession` delegate methods for the forwarding to work.
@interface EMBURLSessionDelegateForwarder : NSObject

- (void)forwardToObject:(NSObject *)object
             URLSession:(nonnull NSURLSession *)session
didBecomeInvalidWithError:(nullable NSError *)error;

- (void)forwardToObject:(NSObject *)object
             URLSession:(nonnull NSURLSession *)session
               dataTask:(nonnull NSURLSessionDataTask *)task
         didReceiveData:(nonnull NSData *)data;

- (void)forwardToObject:(NSObject *)object
             URLSession:(nonnull NSURLSession *)session
                   task:(nonnull NSURLSessionTask *)task
didFinishCollectiongMetrics:(nonnull NSURLSessionTaskMetrics *)metrics;

- (void)forwardToObject:(NSObject *)object
             URLSession:(nonnull NSURLSession *)session
                   task:(nonnull NSURLSessionTask *)task
   didCompleteWithError:(nullable NSError *)error;

- (void)forwardToObject:(NSObject *)object
             URLSession:(nonnull NSURLSession *)session
           downloadTask:(nonnull NSURLSessionDownloadTask *)task
didFinishDownloadingToURL:(nonnull NSURL *)url;

@end

NS_ASSUME_NONNULL_END
