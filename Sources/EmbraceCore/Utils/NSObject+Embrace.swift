//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceOTelInternal

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
