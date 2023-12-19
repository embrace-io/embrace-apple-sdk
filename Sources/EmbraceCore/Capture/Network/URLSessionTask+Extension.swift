//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension URLSessionTask {
    private struct AssociatedKeys {
        static var embraceData: UInt8 = 8
    }

    var embraceData: Data? {
        get {
            return objc_getAssociatedObject(self,
                                            &AssociatedKeys.embraceData) as? Data
        }
        set {
            objc_setAssociatedObject(self,
                                     &AssociatedKeys.embraceData,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
