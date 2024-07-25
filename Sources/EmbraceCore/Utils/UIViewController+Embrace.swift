//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
#if canImport(UIKit)

import UIKit
import EmbraceCommonInternal

extension UIViewController {
    var embViewName: String {
        var title: String?

        if let customized = self as? EmbraceViewControllerCustomization {
            title = customized.nameForViewControllerInEmbrace
        } else {
            title = self.title
        }

        return title ?? ""
    }

    var embCaptureView: Bool {
        if let customized = self as? EmbraceViewControllerCustomization {
            return customized.shouldCaptureViewInEmbrace
        }

        return true
    }
}

#endif
