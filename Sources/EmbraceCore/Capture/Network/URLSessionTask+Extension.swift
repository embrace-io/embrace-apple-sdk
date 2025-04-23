//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension URLSessionTask {
    private struct AssociatedKeys {
        static var embraceCaptured: UInt8 = 0
        static var embraceData: UInt8 = 1
        static var embraceStartTime: UInt8 = 2
    }

    var embraceCaptured: Bool {
        get {
            if let value = objc_getAssociatedObject(self, &AssociatedKeys.embraceCaptured) as? NSNumber {
                return value.boolValue
            }

            return false
        }

        set {
            let value: NSNumber = NSNumber(booleanLiteral: newValue)
            objc_setAssociatedObject(self,
                                     &AssociatedKeys.embraceCaptured,
                                     value,
                                     .OBJC_ASSOCIATION_RETAIN)
        }
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
                                     .OBJC_ASSOCIATION_COPY)
        }
    }

    var embraceStartTime: Date? {
        get {
            return objc_getAssociatedObject(self,
                                            &AssociatedKeys.embraceStartTime) as? Date
        }
        set {
            objc_setAssociatedObject(self,
                                     &AssociatedKeys.embraceStartTime,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN)
        }
    }
}
