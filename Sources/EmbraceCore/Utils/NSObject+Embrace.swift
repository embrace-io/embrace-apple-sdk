//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceOTelInternal
#endif
import OpenTelemetryApi

extension NSObject {
    private struct AssociatedKeys {
        static var embraceSpanKey: UInt8 = 8
    }

    var emb_associatedSpan: Span? {
        get {
            return objc_getAssociatedObject(self,
                                            &AssociatedKeys.embraceSpanKey) as? Span
        }
        set {
            objc_setAssociatedObject(self,
                                     &AssociatedKeys.embraceSpanKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
