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
    /// If no erro code is passed, the status will be set to `.ok`.
    /// - Parameters:
    ///   - errorCode: Error code for the span
    ///   - endTime: Time when the span ended
    public func end(errorCode: EmbraceSpanErrorCode? = nil, endTime: Date = Date()) {
        if let errorCode {
            setInternalAttribute(key: SpanSemantics.keyErrorCode, value: errorCode.name)
            setStatus(.error)
        } else {
            setStatus(.ok)
        }

        end(endTime: endTime)
    }
}
