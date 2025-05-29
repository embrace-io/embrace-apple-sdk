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


void proxy_URLSession_task_willPerformHTTPRedirection(id self, SEL _cmd,
                                                      NSURLSession *session,
                                                      NSURLSessionTask *task,
                                                      NSHTTPURLResponse *response,
                                                      NSURLRequest *request,
                                                      void (^completionHandler)(NSURLRequest *));

void proxy_URLSession_didReceiveChallenge(id self, SEL _cmd,
                                          NSURLSession *session,
                                          NSURLAuthenticationChallenge *challenge,
                                          void (^completionHandler)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential));

void proxy_URLSessionDidFinishEventsForBackgroundURLSession(id self, SEL _cmd,
                                                            NSURLSession *session);

void proxy_URLSession_didCreateTask(id self, SEL _cmd,
                                    NSURLSession *session,
                                    NSURLSessionTask *task);

void proxy_URLSession_task_willBeginDelayedRequest(id self, SEL _cmd,
                                                   NSURLSession *session,
                                                   NSURLSessionTask *task,
                                                   NSURLRequest *request,
                                                   void (^completionHandler)(NSURLSessionDelayedRequestDisposition disposition, NSURLRequest * _Nullable newRequest));

void proxy_URLSession_taskIsWaitingForConnectivity(id self, SEL _cmd,
                                                   NSURLSession *session,
                                                   NSURLSessionTask *task);

void proxy_URLSession_task_didReceiveChallenge(id self, SEL _cmd,
                                               NSURLSession *session,
                                               NSURLSessionTask *task,
                                               NSURLAuthenticationChallenge *challenge,
                                               void (^completionHandler)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential));

void proxy_URLSession_task_needNewBodyStream(id self, SEL _cmd,
                                             NSURLSession *session,
                                             NSURLSessionTask *task,
                                             void (^completionHandler)(NSInputStream * _Nullable bodyStream));

void proxy_URLSession_task_needNewBodyStreamFromOffset(id self, SEL _cmd,
                                                       NSURLSession *session,
                                                       NSURLSessionTask *task,
                                                       int64_t offset,
                                                       void (^completionHandler)(NSInputStream * _Nullable bodyStream));

void proxy_URLSession_task_didSendBodyData(id self, SEL _cmd,
                                           NSURLSession *session,
                                           NSURLSessionTask *task,
                                           int64_t bytesSent,
                                           int64_t totalBytesSent,
                                           int64_t totalBytesExpectedToSend);

void proxy_URLSession_task_didReceiveInformationalResponse(id self, SEL _cmd,
                                                           NSURLSession *session,
                                                           NSURLSessionTask *task,
                                                           NSHTTPURLResponse *response);

void proxy_URLSession_dataTask_didBecomeDownloadTask(id self, SEL _cmd,
                                                     NSURLSession *session,
                                                     NSURLSessionDataTask *dataTask,
                                                     NSURLSessionDownloadTask *downloadTask);

void proxy_URLSession_dataTask_didBecomeStreamTask(id self, SEL _cmd,
                                                   NSURLSession *session,
                                                   NSURLSessionDataTask *dataTask,
                                                   NSURLSessionStreamTask *streamTask);

void proxy_URLSession_dataTask_willCacheResponse(id self, SEL _cmd,
                                                 NSURLSession *session,
                                                 NSURLSessionDataTask *dataTask,
                                                 NSCachedURLResponse *proposedResponse,
                                                 void (^completionHandler)(NSCachedURLResponse * _Nullable cachedResponse));

void proxy_URLSession_downloadTask_didWriteData(id self, SEL _cmd,
                                                NSURLSession *session,
                                                NSURLSessionDownloadTask *downloadTask,
                                                int64_t bytesWritten,
                                                int64_t totalBytesWritten,
                                                int64_t totalBytesExpectedToWrite);

void proxy_URLSession_downloadTask_didResumeAtOffset(id self, SEL _cmd,
                                                     NSURLSession *session,
                                                     NSURLSessionDownloadTask *downloadTask,
                                                     int64_t fileOffset,
                                                     int64_t expectedTotalBytes);

void proxy_URLSession_readClosedForStreamTask(id self, SEL _cmd,
                                              NSURLSession *session,
                                              NSURLSessionStreamTask *streamTask);

void proxy_URLSession_writeClosedForStreamTask(id self, SEL _cmd,
                                               NSURLSession *session,
                                               NSURLSessionStreamTask *streamTask);

void proxy_URLSession_betterRouteDiscoveredForStreamTask(id self, SEL _cmd,
                                                         NSURLSession *session,
                                                         NSURLSessionStreamTask *streamTask);

void proxy_URLSession_streamTask_didBecomeInputStream_outputStream(id self, SEL _cmd,
                                                                   NSURLSession *session,
                                                                   NSURLSessionStreamTask *streamTask,
                                                                   NSInputStream *inputStream,
                                                                   NSOutputStream *outputStream);

NS_ASSUME_NONNULL_END
