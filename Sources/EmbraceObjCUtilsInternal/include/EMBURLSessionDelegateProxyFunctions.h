//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define WILL_PERFORM_REDIRECTION @selector(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:)
#define DID_RECEIVE_CHALLENGE @selector(URLSession:didReceiveChallenge:completionHandler:)
#define DID_FINISH_EVENTS_BACKGROUND @selector(URLSessionDidFinishEventsForBackgroundURLSession:)
#define DID_CREATE_TASK @selector(URLSession:didCreateTask:)
#define WILL_BEGIN_DELAYED_REQUEST @selector(URLSession:task:willBeginDelayedRequest:completionHandler:)
#define IS_WAITING_FOR_CONNECTIVITY @selector(URLSession:taskIsWaitingForConnectivity:)
#define TASK_DID_RECEIVE_CHALLENGE @selector(URLSession:task:didReceiveChallenge:completionHandler:)
#define TASK_NEED_NEW_BODY_STREAM @selector(URLSession:task:needNewBodyStream:)
#define TASK_NEED_NEW_BODY_STREAM_OFFSET @selector(URLSession:task:needNewBodyStreamFromOffset:completionHandler:)
#define TASK_DID_SEND_BODY_DATA @selector(URLSession:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:)
#define TASK_DID_RECEIVE_INFO_RESPONSE @selector(URLSession:task:didReceiveInformationalResponse:)
#define DATATASK_BECOME_DOWNLOADTASK @selector(URLSession:dataTask:didBecomeDownloadTask:)
#define DATATASK_BECOME_STREAMTASK @selector(URLSession:dataTask:didBecomeStreamTask:)
#define DATATASK_WILL_CACHE_RESPONSE @selector(URLSession:dataTask:willCacheResponse:completionHandler:)
#define DOWNLOADTASK_DID_WRITE_DATA @selector(URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:)
#define DOWNLOADTASK_DID_RESUME @selector(URLSession:downloadTask:didResumeAtOffset:expectedTotalBytes:)
#define READ_CLOSED_STREAMTASK @selector(URLSession:readClosedForStreamTask:)
#define WRITE_CLOSED_STREAMTASK @selector(URLSession:writeClosedForStreamTask:)
#define BETTER_ROUTE_DISCOVERED @selector(URLSession:betterRouteDiscoveredForStreamTask:)
#define STREAMTASK_BECOME_STREAMS @selector(URLSession:streamTask:didBecomeInputStream:outputStream:)


void proxy_URLSession_task_willPerformHTTPRedirection(id _Nonnull self, SEL _Nonnull _cmd,
                                                      NSURLSession * _Nonnull session,
                                                      NSURLSessionTask * _Nonnull task,
                                                      NSHTTPURLResponse * _Nonnull response,
                                                      NSURLRequest * _Nonnull request,
                                                      void (^ _Nonnull completionHandler)(NSURLRequest * _Nullable));

void proxy_URLSession_didReceiveChallenge(id _Nonnull self, SEL _Nonnull _cmd,
                                          NSURLSession * _Nonnull session,
                                          NSURLAuthenticationChallenge * _Nonnull challenge,
                                          void (^ _Nonnull completionHandler)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential));

void proxy_URLSessionDidFinishEventsForBackgroundURLSession(id _Nonnull self, SEL _Nonnull _cmd,
                                                            NSURLSession * _Nonnull session);

void proxy_URLSession_didCreateTask(id _Nonnull self, SEL _Nonnull _cmd,
                                    NSURLSession * _Nonnull session,
                                    NSURLSessionTask * _Nonnull task);

void proxy_URLSession_task_willBeginDelayedRequest(id _Nonnull self, SEL _Nonnull _cmd,
                                                   NSURLSession * _Nonnull session,
                                                   NSURLSessionTask * _Nonnull task,
                                                   NSURLRequest * _Nonnull request,
                                                   void (^ _Nonnull completionHandler)(NSURLSessionDelayedRequestDisposition disposition, NSURLRequest * _Nullable newRequest));

void proxy_URLSession_taskIsWaitingForConnectivity(id _Nonnull self, SEL _Nonnull _cmd,
                                                   NSURLSession * _Nonnull session,
                                                   NSURLSessionTask * _Nonnull task);

void proxy_URLSession_task_didReceiveChallenge(id _Nonnull self, SEL _Nonnull _cmd,
                                               NSURLSession * _Nonnull session,
                                               NSURLSessionTask * _Nonnull task,
                                               NSURLAuthenticationChallenge * _Nonnull challenge,
                                               void (^ _Nonnull completionHandler)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential));

void proxy_URLSession_task_needNewBodyStream(id _Nonnull self, SEL _Nonnull _cmd,
                                             NSURLSession * _Nonnull session,
                                             NSURLSessionTask * _Nonnull task,
                                             void (^ _Nonnull completionHandler)(NSInputStream * _Nullable bodyStream));

void proxy_URLSession_task_needNewBodyStreamFromOffset(id _Nonnull self, SEL _Nonnull _cmd,
                                                       NSURLSession * _Nonnull session,
                                                       NSURLSessionTask * _Nonnull task,
                                                       int64_t offset,
                                                       void (^ _Nonnull completionHandler)(NSInputStream * _Nullable bodyStream));

void proxy_URLSession_task_didSendBodyData(id _Nonnull self, SEL _Nonnull _cmd,
                                           NSURLSession * _Nonnull session,
                                           NSURLSessionTask * _Nonnull task,
                                           int64_t bytesSent,
                                           int64_t totalBytesSent,
                                           int64_t totalBytesExpectedToSend);

void proxy_URLSession_task_didReceiveInformationalResponse(id _Nonnull self, SEL _Nonnull _cmd,
                                                           NSURLSession * _Nonnull session,
                                                           NSURLSessionTask * _Nonnull task,
                                                           NSHTTPURLResponse * _Nonnull response);

void proxy_URLSession_dataTask_didBecomeDownloadTask(id _Nonnull self, SEL _Nonnull _cmd,
                                                     NSURLSession * _Nonnull session,
                                                     NSURLSessionDataTask * _Nonnull dataTask,
                                                     NSURLSessionDownloadTask * _Nonnull downloadTask);

void proxy_URLSession_dataTask_didBecomeStreamTask(id _Nonnull self, SEL _Nonnull _cmd,
                                                   NSURLSession * _Nonnull session,
                                                   NSURLSessionDataTask * _Nonnull dataTask,
                                                   NSURLSessionStreamTask * _Nonnull streamTask);

void proxy_URLSession_dataTask_willCacheResponse(id _Nonnull self, SEL _Nonnull _cmd,
                                                 NSURLSession * _Nonnull session,
                                                 NSURLSessionDataTask * _Nonnull dataTask,
                                                 NSCachedURLResponse * _Nonnull proposedResponse,
                                                 void (^ _Nonnull completionHandler)(NSCachedURLResponse * _Nullable cachedResponse));

void proxy_URLSession_downloadTask_didWriteData(id _Nonnull self, SEL _Nonnull _cmd,
                                                NSURLSession * _Nonnull session,
                                                NSURLSessionDownloadTask * _Nonnull downloadTask,
                                                int64_t bytesWritten,
                                                int64_t totalBytesWritten,
                                                int64_t totalBytesExpectedToWrite);

void proxy_URLSession_downloadTask_didResumeAtOffset(id _Nonnull self, SEL _Nonnull _cmd,
                                                     NSURLSession * _Nonnull session,
                                                     NSURLSessionDownloadTask * _Nonnull downloadTask,
                                                     int64_t fileOffset,
                                                     int64_t expectedTotalBytes);

void proxy_URLSession_readClosedForStreamTask(id _Nonnull self, SEL _Nonnull _cmd,
                                              NSURLSession * _Nonnull session,
                                              NSURLSessionStreamTask * _Nonnull streamTask);

void proxy_URLSession_writeClosedForStreamTask(id _Nonnull self, SEL _Nonnull _cmd,
                                               NSURLSession * _Nonnull session,
                                               NSURLSessionStreamTask * _Nonnull streamTask);

void proxy_URLSession_betterRouteDiscoveredForStreamTask(id _Nonnull self, SEL _Nonnull _cmd,
                                                         NSURLSession * _Nonnull session,
                                                         NSURLSessionStreamTask * _Nonnull streamTask);

void proxy_URLSession_streamTask_didBecomeInputStream_outputStream(id _Nonnull self, SEL _Nonnull _cmd,
                                                                   NSURLSession * _Nonnull session,
                                                                   NSURLSessionStreamTask * _Nonnull streamTask,
                                                                   NSInputStream * _Nonnull inputStream,
                                                                   NSOutputStream * _Nonnull outputStream);

NS_ASSUME_NONNULL_END
