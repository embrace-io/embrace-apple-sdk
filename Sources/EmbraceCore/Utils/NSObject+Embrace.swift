//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceOTelInternal
#endif

extension NSObject {
    private struct AssociatedKeys {
        static let embraceSpanKey: UInt8 = 8
    }

    var emb_associatedSpan: Span? {
        get {
            var key = AssociatedKeys.embraceSpanKey
            return objc_getAssociatedObject(
                self,
                &key) as? Span
        }
        set {
            var key = AssociatedKeys.embraceSpanKey
            objc_setAssociatedObject(
                self,
                &key,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
