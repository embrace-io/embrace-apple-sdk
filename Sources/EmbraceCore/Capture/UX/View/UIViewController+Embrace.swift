//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
import Foundation
import UIKit

extension UIViewController {
    private struct AssociatedKeys {
        static var embraceIdentifier: Int = 0
    }

    var emb_identifier: String? {
        get {
            if let value = objc_getAssociatedObject(self, &AssociatedKeys.embraceIdentifier) as? NSString {
                return value as String
            }

            return nil
        }

        set {
            objc_setAssociatedObject(self,
                                     &AssociatedKeys.embraceIdentifier,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN)
        }
    }

    var emb_viewName: String {
        var title: String?

        if let customized = self as? EmbraceViewControllerCustomization {
            title = customized.nameForViewControllerInEmbrace
        }

        return title ?? className
    }

    var emb_shouldCaptureView: Bool {
        if let customized = self as? EmbraceViewControllerCustomization {
            return customized.shouldCaptureViewInEmbrace
        }

        return true
    }

    var className: String {
        return String(describing: type(of: self))
    }
}
#endif
