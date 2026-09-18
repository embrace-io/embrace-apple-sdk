//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

extension EmbraceSpan {
    /// Ends the span with the given `EmbraceSpanErrorCode`.
    /// This adds an Embrace specific attribute with the code, and sets the status to `.error`.
    /// If no error code is passed, the status will be set to `.ok`.
    /// A span that already ended keeps the status and error code it ended with.
    /// - Parameters:
    ///   - errorCode: Error code for the span
    ///   - endTime: Time when the span ended
    public func end(errorCode: EmbraceSpanErrorCode? = nil, endTime: Date = Date()) {
        // The SDK's own spans claim the status, the error code and the end time together, so a
        // plain `end()` racing this call can't leave the span holding half of the outcome.
        if let span = self as? EmbraceSpanErrorCodeEnd {
            span._end(errorCode: errorCode, endTime: endTime)
            return
        }

        // Any other conformer — a test double, a read-only adapter — has no shared state to claim,
        // so its outcome is recorded one step at a time.
        endOneStepAtATime(errorCode: errorCode, endTime: endTime)
    }

    private func endOneStepAtATime(errorCode: EmbraceSpanErrorCode?, endTime: Date) {
        guard self.endTime == nil else {
            return
        }

        if let errorCode {
            setInternalAttribute(key: SpanSemantics.keyErrorCode, value: errorCode.name)
            setStatus(.error)
        } else {
            setStatus(.ok)
        }

        end(endTime: endTime)
    }
}
