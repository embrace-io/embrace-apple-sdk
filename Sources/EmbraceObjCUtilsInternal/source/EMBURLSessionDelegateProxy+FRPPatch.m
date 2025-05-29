//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "objc/runtime.h"
#import "EMBURLSessionDelegateProxy.h"
#import "EMBURLSessionDelegateProxyFunctions.h"

@interface EMBURLSessionDelegateProxy (FRPPatch)
@end

@implementation EMBURLSessionDelegateProxy (FRPPatch)

/**
 This logic is only required to ensure our proxy (`EMBURLSessionDelegateProxy`) works correctly
 when Firebase Performance (FPR) is present.

 The problem arises when FPR performs method swizzling on our proxy. Depending on which component
 initializes first, it's possible that Firebase ends up swizzling our instance of `EMBURLSessionDelegateProxy`.

 In general, this wouldn’t be an issue. However, when FPR detects that an object is a proxy (`isProxy == YES`),
 it installs its own implementation of `respondsToSelector:`. Internally, this custom implementation uses
 `instancesRespondToSelector:` on the class instead of calling the proxy’s own `respondsToSelector:` logic.

 This behavior breaks our delegation model, which dynamically checks at runtime whether the proxied object
 responds to a given selector.

 To prevent messages from being dropped due to this behavior, we manually (and dynamically) add all the relevant
 `NSURLSession*Delegate` methods to our class at runtime using `class_addMethod`. This ensures that
 `instancesRespondToSelector:` returns `YES` for these methods.

 The method injection is done in `+initialize`, guarded by `dispatch_once`, and only triggered if we
 detect that FPR is present (`FPRSwizzledObject` exists in the runtime). While it's not a typical pattern
 for proxy classes to implement methods they don't own, this is the safest way to ensure compatibility
 with Firebase’s swizzling approach (unless Firebase updates its logic to properly respect `respondsToSelector:`
 in proxy scenarios).
*/
+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class firebaseClass = NSClassFromString(@"FPRSwizzledObject");
        if (firebaseClass) {
            class_addMethod(self, WILL_PERFORM_REDIRECTION, (IMP)proxy_URLSession_task_willPerformHTTPRedirection, "v@:@@@@@");
            class_addMethod(self, DID_RECEIVE_CHALLENGE, (IMP)proxy_URLSession_didReceiveChallenge, "v@:@@?");
            class_addMethod(self, DID_FINISH_EVENTS_BACKGROUND, (IMP)proxy_URLSessionDidFinishEventsForBackgroundURLSession, "v@:@");
            class_addMethod(self, DID_CREATE_TASK, (IMP)proxy_URLSession_didCreateTask, "v@:@@");
            class_addMethod(self, WILL_BEGIN_DELAYED_REQUEST, (IMP)proxy_URLSession_task_willBeginDelayedRequest, "v@:@@@@?");
            class_addMethod(self, IS_WAITING_FOR_CONNECTIVITY, (IMP)proxy_URLSession_taskIsWaitingForConnectivity, "v@:@@");
            class_addMethod(self, TASK_DID_RECEIVE_CHALLENGE, (IMP)proxy_URLSession_task_didReceiveChallenge, "v@:@@@?");
            class_addMethod(self, TASK_NEED_NEW_BODY_STREAM, (IMP)proxy_URLSession_task_needNewBodyStream, "v@:@@?");
            class_addMethod(self, TASK_NEED_NEW_BODY_STREAM_OFFSET, (IMP)proxy_URLSession_task_needNewBodyStreamFromOffset, "v@:@@q@?");
            class_addMethod(self, TASK_DID_SEND_BODY_DATA, (IMP)proxy_URLSession_task_didSendBodyData, "v@:@@qqq");
            class_addMethod(self, TASK_DID_RECEIVE_INFO_RESPONSE, (IMP)proxy_URLSession_task_didReceiveInformationalResponse, "v@:@@@");
            class_addMethod(self, DATATASK_BECOME_DOWNLOADTASK, (IMP)proxy_URLSession_dataTask_didBecomeDownloadTask, "v@:@@@");
            class_addMethod(self, DATATASK_BECOME_STREAMTASK, (IMP)proxy_URLSession_dataTask_didBecomeStreamTask, "v@:@@@");
            class_addMethod(self, DATATASK_WILL_CACHE_RESPONSE, (IMP)proxy_URLSession_dataTask_willCacheResponse, "v@:@@@?");
            class_addMethod(self, DOWNLOADTASK_DID_WRITE_DATA, (IMP)proxy_URLSession_downloadTask_didWriteData, "v@:@@qqq");
            class_addMethod(self, DOWNLOADTASK_DID_RESUME, (IMP)proxy_URLSession_downloadTask_didResumeAtOffset, "v@:@@qq");
            class_addMethod(self, READ_CLOSED_STREAMTASK, (IMP)proxy_URLSession_readClosedForStreamTask, "v@:@@");
            class_addMethod(self, WRITE_CLOSED_STREAMTASK, (IMP)proxy_URLSession_writeClosedForStreamTask, "v@:@@");
            class_addMethod(self, BETTER_ROUTE_DISCOVERED, (IMP)proxy_URLSession_betterRouteDiscoveredForStreamTask, "v@:@@");
            class_addMethod(self, STREAMTASK_BECOME_STREAMS, (IMP)proxy_URLSession_streamTask_didBecomeInputStream_outputStream, "v@:@@@@");
        }
    });
}

@end
