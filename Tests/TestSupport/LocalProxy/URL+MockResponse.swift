//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension URL {

    struct Keys {
        nonisolated(unsafe) static var mockResponseKey: UInt8 = 2
    }

    public var mockResponse: URLTestProxiedResponse? {
        get {
            return objc_getAssociatedObject(self, &Keys.mockResponseKey) as? URLTestProxiedResponse
        }
        set {
            objc_setAssociatedObject(
                self,
                &Keys.mockResponseKey,
                newValue,
                objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}
