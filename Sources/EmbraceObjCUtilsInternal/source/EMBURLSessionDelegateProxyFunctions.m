//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "EMBURLSessionDelegateProxy.h"

void proxy_URLSession_task_willPerformHTTPRedirection(id self, SEL _cmd, NSURLSession *session, NSURLSessionTask *task,
                                                      NSHTTPURLResponse *response, NSURLRequest *request,

                                                      void (^completionHandler)(NSURLRequest *))
{
    id target = [((EMBURLSessionDelegateProxy *)self) getTargetForSelector:_cmd session:session];

    if (target) {
        [(id<NSURLSessionTaskDelegate>)target URLSession:session
                                                    task:task
                              willPerformHTTPRedirection:response
                                              newRequest:request
                                       completionHandler:completionHandler];
    } else {
        completionHandler(request);
    }
}

void proxy_URLSession_didReceiveChallenge(id self, SEL _cmd, NSURLSession *session,
                                          NSURLAuthenticationChallenge *challenge,
                                          void (^completionHandler)(NSURLSessionAuthChallengeDisposition disposition,
                                                                    NSURLCredential *_Nullable credential))
{
    id target = [((EMBURLSessionDelegateProxy *)self) getTargetForSelector:_cmd session:session];
    if (target) {
        [target URLSession:session didReceiveChallenge:challenge completionHandler:completionHandler];
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

void proxy_URLSessionDidFinishEventsForBackgroundURLSession(id self, SEL _cmd, NSURLSession *session)
{
    id target = [((EMBURLSessionDelegateProxy *)self) getTargetForSelector:_cmd session:session];
    if (target) {
        [target URLSessionDidFinishEventsForBackgroundURLSession:session];
    }
}

void proxy_URLSession_didCreateTask(id self, SEL _cmd, NSURLSession *session, NSURLSessionTask *task)
{
    id target = [((EMBURLSessionDelegateProxy *)self) getTargetForSelector:_cmd session:session];
    if (target) {
        if (@available(iOS 16.0, tvOS 16.0, *)) {
            [target URLSession:session didCreateTask:task];
        }
    }
}

void proxy_URLSession_task_willBeginDelayedRequest(
    id self, SEL _cmd, NSURLSession *session, NSURLSessionTask *task, NSURLRequest *request,
    void (^completionHandler)(NSURLSessionDelayedRequestDisposition disposition, NSURLRequest *_Nullable newRequest))
{
    id target = [((EMBURLSessionDelegateProxy *)self) getTargetForSelector:_cmd session:session];
    if (target) {
        [target URLSession:session task:task willBeginDelayedRequest:request completionHandler:completionHandler];
    } else {
        completionHandler(NSURLSessionDelayedRequestContinueLoading, request);
    }
}

void proxy_URLSession_taskIsWaitingForConnectivity(id self, SEL _cmd, NSURLSession *session, NSURLSessionTask *task)
{
    id target = [((EMBURLSessionDelegateProxy *)self) getTargetForSelector:_cmd session:session];
    if (target) {
        [target URLSession:session taskIsWaitingForConnectivity:task];
    }
}

void proxy_URLSession_task_didReceiveChallenge(
    id self, SEL _cmd, NSURLSession *session, NSURLSessionTask *task, NSURLAuthenticationChallenge *challenge,
    void (^completionHandler)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *_Nullable credential))
{
    id target = [((EMBURLSessionDelegateProxy *)self) getTargetForSelector:_cmd session:session];
    if (target) {
        [target URLSession:session task:task didReceiveChallenge:challenge completionHandler:completionHandler];
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

void proxy_URLSession_task_needNewBodyStream(id self, SEL _cmd, NSURLSession *session, NSURLSessionTask *task,
                                             void (^completionHandler)(NSInputStream *_Nullable bodyStream))
{
    id target = [((EMBURLSessionDelegateProxy *)self) getTargetForSelector:_cmd session:session];
    if (target) {
        [target URLSession:session task:task needNewBodyStream:completionHandler];
    } else {
        completionHandler(nil);
    }
}

void proxy_URLSession_task_needNewBodyStreamFromOffset(id self, SEL _cmd, NSURLSession *session, NSURLSessionTask *task,
                                                       int64_t offset,
                                                       void (^completionHandler)(NSInputStream *_Nullable bodyStream))
{
    id target = [((EMBURLSessionDelegateProxy *)self) getTargetForSelector:_cmd session:session];
    if (target) {
        if (@available(iOS 17.0, tvOS 17.0, macOS 14.0, *)) {
            [target URLSession:session
                                       task:task
                needNewBodyStreamFromOffset:offset
                          completionHandler:completionHandler];
        }
    } else {
        completionHandler(nil);
    }
}

void proxy_URLSession_task_didSendBodyData(id self, SEL _cmd, NSURLSession *session, NSURLSessionTask *task,
                                           int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend)
{
    id target = [((EMBURLSessionDelegateProxy *)self) getTargetForSelector:_cmd session:session];
    if (target) {
        [target URLSession:session
                                task:task
                     didSendBodyData:bytesSent
                      totalBytesSent:totalBytesSent
            totalBytesExpectedToSend:totalBytesExpectedToSend];
    }
}

void proxy_URLSession_task_didReceiveInformationalResponse(id self, SEL _cmd, NSURLSession *session,
                                                           NSURLSessionTask *task, NSHTTPURLResponse *response)
{
    id target = [((EMBURLSessionDelegateProxy *)self) getTargetForSelector:_cmd session:session];
    if (target) {
        if (@available(iOS 17.0, tvOS 17.0, macOS 14.0, *)) {
            [target URLSession:session task:task didReceiveInformationalResponse:response];
        }
    }
}

void proxy_URLSession_dataTask_didBecomeDownloadTask(id self, SEL _cmd, NSURLSession *session,
                                                     NSURLSessionDataTask *dataTask,
                                                     NSURLSessionDownloadTask *downloadTask)
{
    id target = [((EMBURLSessionDelegateProxy *)self) getTargetForSelector:_cmd session:session];
    if (target) {
        [target URLSession:session dataTask:dataTask didBecomeDownloadTask:downloadTask];
    }
}

void proxy_URLSession_dataTask_didBecomeStreamTask(id self, SEL _cmd, NSURLSession *session,
                                                   NSURLSessionDataTask *dataTask, NSURLSessionStreamTask *streamTask)
{
    id target = [((EMBURLSessionDelegateProxy *)self) getTargetForSelector:_cmd session:session];
    if (target) {
        [target URLSession:session dataTask:dataTask didBecomeStreamTask:streamTask];
    }
}

void proxy_URLSession_dataTask_willCacheResponse(
    id self, SEL _cmd, NSURLSession *session, NSURLSessionDataTask *dataTask, NSCachedURLResponse *proposedResponse,
    void (^completionHandler)(NSCachedURLResponse *_Nullable cachedResponse))
{
    id target = [((EMBURLSessionDelegateProxy *)self) getTargetForSelector:_cmd session:session];
    if (target) {
        [target URLSession:session
                     dataTask:dataTask
            willCacheResponse:proposedResponse
            completionHandler:completionHandler];
    } else {
        completionHandler(proposedResponse);
    }
}

void proxy_URLSession_downloadTask_didWriteData(id self, SEL _cmd, NSURLSession *session,
                                                NSURLSessionDownloadTask *downloadTask, int64_t bytesWritten,
                                                int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite)
{
    id target = [((EMBURLSessionDelegateProxy *)self) getTargetForSelector:_cmd session:session];
    if (target) {
        [target URLSession:session
                         downloadTask:downloadTask
                         didWriteData:bytesWritten
                    totalBytesWritten:totalBytesWritten
            totalBytesExpectedToWrite:totalBytesExpectedToWrite];
    }
}

void proxy_URLSession_downloadTask_didResumeAtOffset(id self, SEL _cmd, NSURLSession *session,
                                                     NSURLSessionDownloadTask *downloadTask, int64_t fileOffset,
                                                     int64_t expectedTotalBytes)
{
    id target = [((EMBURLSessionDelegateProxy *)self) getTargetForSelector:_cmd session:session];
    if (target) {
        [target URLSession:session
                  downloadTask:downloadTask
             didResumeAtOffset:fileOffset
            expectedTotalBytes:expectedTotalBytes];
    }
}

void proxy_URLSession_readClosedForStreamTask(id self, SEL _cmd, NSURLSession *session,
                                              NSURLSessionStreamTask *streamTask)
{
    id target = [((EMBURLSessionDelegateProxy *)self) getTargetForSelector:_cmd session:session];
    if (target) {
        [target URLSession:session readClosedForStreamTask:streamTask];
    }
}

void proxy_URLSession_writeClosedForStreamTask(id self, SEL _cmd, NSURLSession *session,
                                               NSURLSessionStreamTask *streamTask)
{
    id target = [((EMBURLSessionDelegateProxy *)self) getTargetForSelector:_cmd session:session];
    if (target) {
        [target URLSession:session writeClosedForStreamTask:streamTask];
    }
}

void proxy_URLSession_betterRouteDiscoveredForStreamTask(id self, SEL _cmd, NSURLSession *session,
                                                         NSURLSessionStreamTask *streamTask)
{
    id target = [((EMBURLSessionDelegateProxy *)self) getTargetForSelector:_cmd session:session];
    if (target) {
        [target URLSession:session betterRouteDiscoveredForStreamTask:streamTask];
    }
}

void proxy_URLSession_streamTask_didBecomeInputStream_outputStream(id self, SEL _cmd, NSURLSession *session,
                                                                   NSURLSessionStreamTask *streamTask,
                                                                   NSInputStream *inputStream,
                                                                   NSOutputStream *outputStream)
{
    id target = [((EMBURLSessionDelegateProxy *)self) getTargetForSelector:_cmd session:session];
    if (target) {
        [target URLSession:session streamTask:streamTask didBecomeInputStream:inputStream outputStream:outputStream];
    }
}
