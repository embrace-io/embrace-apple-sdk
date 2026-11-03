//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCore
    import EmbraceSemantics
#endif

/// Network span parent
extension EmbraceIO {

    /// Sets the span that every network span started from now on is parented to.
    ///
    /// Use it to put the requests made during a flow under the span that represents that flow.
    /// Only network spans captured by the SDK are affected; other spans are unaffected.
    ///
    /// - There is one network span parent at a time. Setting a new one replaces the previous one.
    ///   Replacing a parent that is still active logs a warning and records a span event on the replaced span.
    /// - The parent is cleared automatically when the span ends, and when the current user session ends.
    ///   Network spans already started keep it as their parent.
    /// - A span that has already ended is rejected with a warning. The previous parent stays.
    ///
    /// This method is thread safe.
    ///
    /// - Parameter span: The span that new network spans are parented to.
    /// - Returns: A token to pass to `clearNetworkSpanParent(_:)`. If the SDK isn't set up or the span
    ///   is rejected, the returned token clears nothing.
    public func setNetworkSpanParent(_ span: EmbraceSpan) -> EmbraceNetworkSpanParentToken {
        guard let controller = Embrace.client?.networkSpanParentController else {
            return .inert
        }
        return controller.set(span: span)
    }

    /// Sets the span with the given context as the parent of every network span started from now on.
    ///
    /// Use it to parent network spans to a span the SDK didn't create, such as one from the app's own
    /// OpenTelemetry pipeline. Only network spans captured by the SDK are affected; other spans are unaffected.
    ///
    /// - There is one network span parent at a time. Setting a new one replaces the previous one.
    ///   Replacing a parent that is still active logs a warning.
    /// - The parent is cleared automatically when the SDK sees a span with this context end, which covers
    ///   spans created through the SDK and through its OpenTelemetry providers, and when the current user
    ///   session ends. For a span the SDK never sees, call `clearNetworkSpanParent(_:)` when the flow ends.
    ///   Network spans already started keep it as their parent.
    /// - A context whose span id isn't 16 hexadecimal characters, or whose trace id isn't 32, or where
    ///   either is entirely made of zeros, is rejected with a warning. The previous parent stays.
    ///
    /// This method is thread safe.
    ///
    /// - Parameter context: The context of the span that new network spans are parented to.
    /// - Returns: A token to pass to `clearNetworkSpanParent(_:)`. If the SDK isn't set up or the context
    ///   is rejected, the returned token clears nothing.
    public func setNetworkSpanParent(_ context: EmbraceSpanContext) -> EmbraceNetworkSpanParentToken {
        guard let controller = Embrace.client?.networkSpanParentController else {
            return .inert
        }
        return controller.set(context: context)
    }

    /// Clears the network span parent set with the given token.
    ///
    /// Does nothing if the parent was replaced or cleared since the token was returned, so a late
    /// call can't clear a parent set afterwards. Network spans already started keep their parent.
    ///
    /// This method is thread safe.
    ///
    /// - Parameter token: The token returned when the parent was set.
    public func clearNetworkSpanParent(_ token: EmbraceNetworkSpanParentToken) {
        Embrace.client?.networkSpanParentController.clear(token: token)
    }
}
