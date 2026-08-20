//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import TestSupportObjc
import XCTest

@testable import EmbraceCore
@testable import EmbraceObjCUtilsInternal

/// Regression tests for a production crash:
///
///   `-[EMBURLSessionDelegateProxy URLSession:webSocketTask:didCloseWithCode:reason:]:
///    unrecognized selector sent to instance 0x...`
///
/// The proxy advertises a selector via `-respondsToSelector:` by mirroring its
/// `originalDelegate`. URLSession/CFNetwork snapshots that capability when the session is
/// created and later delivers the callback *raw* — without re-checking `-respondsToSelector:`.
/// If the `originalDelegate` was released in the meantime (e.g. the session was invalidated
/// while a WebSocket close was still in flight), the forwarding path used to fall through to
/// `-doesNotRecognizeSelector:` and crash.
///
/// The proxy must instead forward to the delegate when it is still alive, or drop the message
/// safely when it is not. These tests reproduce the raw delivery that bypasses the usual
/// `-respondsToSelector:` guard; if the fix regresses, they surface the same unrecognized
/// selector exception.
final class URLSessionDelegateProxyWebSocketInvalidationTests: XCTestCase {

    private let closeSelector = NSSelectorFromString("URLSession:webSocketTask:didCloseWithCode:reason:")

    func test_webSocketClose_afterOriginalDelegateReleased_forwardsWhileAlive() {
        assertForwardsCloseWhileDelegateAlive(makeProxy: makeProxy)
    }

    func test_webSocketClose_afterOriginalDelegateDeallocated_dropsSafely() {
        assertDropsCloseWhenDelegateDeallocated(makeProxy: makeProxy)
    }

    // MARK: - Scenarios

    /// Session invalidation clears the proxy's strong reference, but the app still owns the
    /// delegate (the proxy's weak backup stays valid) — so the close must still reach it.
    private func assertForwardsCloseWhileDelegateAlive(
        makeProxy: (WebSocketImplementingURLSessionDelegate) -> AnyObject
    ) {
        let delegate = WebSocketImplementingURLSessionDelegate()
        let sut = makeProxy(delegate)

        EMBClearOriginalDelegate(sut)

        rawInvokeClose(on: sut)

        XCTAssertTrue(delegate.didInvokeDidCloseWithCode)
    }

    /// The proxy held the last strong reference, so nil-ing it deallocates the delegate.
    /// There is nothing to forward to — the close must be dropped rather than crash.
    private func assertDropsCloseWhenDelegateDeallocated(
        makeProxy: (WebSocketImplementingURLSessionDelegate) -> AnyObject
    ) {
        var sut: AnyObject!
        autoreleasepool {
            let delegate = WebSocketImplementingURLSessionDelegate()
            sut = makeProxy(delegate)
            EMBClearOriginalDelegate(sut)
            // `delegate` deallocates at the end of this scope; the proxy's weak backup zeroes out.
        }

        rawInvokeClose(on: sut)
    }

    // MARK: - Helpers

    // Returns `AnyObject` so the scenarios below only ever message the proxy raw, the way
    // CFNetwork does — never through the typed `EMBURLSessionDelegateProxyType` surface.
    private func makeProxy(_ delegate: WebSocketImplementingURLSessionDelegate) -> AnyObject {
        EmbraceMakeURLSessionDelegateProxy(delegate, MockURLSessionTaskHandler())
    }

    private func rawInvokeClose(on proxy: AnyObject) {
        let task = URLSession.shared.webSocketTask(with: URL(string: "wss://embrace.io")!)
        EMBRawInvoke(
            proxy,
            closeSelector,
            WebSocketImplementingURLSessionDelegate.self,
            [
                URLSession.shared,
                task,
                // Scalar `closeCode` slot; the value is never read by the reproduced callback.
                NSNumber(value: URLSessionWebSocketTask.CloseCode.abnormalClosure.rawValue),
                Data()
            ]
        )
    }
}
