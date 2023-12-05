//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public protocol SwizzleCaptureService: InstalledCaptureService {
    func replace(_ originalSelector: Selector, with newSelector: Selector, from containerClass: AnyClass)
}

public extension SwizzleCaptureService {
    func replace(_ originalSelector: Selector, with newSelector: Selector, from containerClass: AnyClass) {
        if let originalInstance = class_getInstanceMethod(containerClass, originalSelector),
           let newInstance = class_getInstanceMethod(containerClass, newSelector) {
            method_exchangeImplementations(originalInstance, newInstance)
        }
    }
}
