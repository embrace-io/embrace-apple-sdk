//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A URLSession delegate that implements the optional WebSocket close callback.
///
/// Used to reproduce a production crash where a delegate that *did* respond to
/// `URLSession:webSocketTask:didCloseWithCode:reason:` was released (e.g. on session
/// invalidation) while that callback was still in flight.
@interface WebSocketImplementingURLSessionDelegate : NSObject <NSURLSessionDelegate>

@property(nonatomic, assign) BOOL didInvokeDidCloseWithCode;

@end

/// Clears the proxy's strong `originalDelegate`, simulating what happens on session
/// invalidation. Kept in Objective-C so the test can poke the proxy through
/// `EMBURLSessionDelegateProxyType` without going through Swift's bridging of the `@objc`
/// protocol.
FOUNDATION_EXPORT void EMBClearOriginalDelegate(id proxy);

/// Sends `selector` to `target` by building an `NSInvocation` and invoking it directly,
/// *without* first checking `-respondsToSelector:`.
///
/// This mirrors how CFNetwork delivers URLSession delegate callbacks: it uses a capability
/// snapshot cached at session-creation time and then messages the delegate raw. That is the
/// exact path that triggers the proxy's forwarding machinery. `signatureSource` supplies the
/// method signature for the selector (typically the original delegate's class), since the
/// proxy may no longer be able to.
FOUNDATION_EXPORT void EMBRawInvoke(id target, SEL selector, Class signatureSource, NSArray *arguments);

NS_ASSUME_NONNULL_END
