//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
    import Foundation
    import UIKit

    extension UIViewController {
        private struct AssociatedKeys {
            nonisolated(unsafe) static var embraceIdentifier: Int = 0
            nonisolated(unsafe) static var anotherIdentifier: Int = 1
        }

        nonisolated
            var emb_instrumentation_state: ViewInstrumentationState?
        {
            get {
                if let value = objc_getAssociatedObject(
                    self,
                    &AssociatedKeys.anotherIdentifier
                ) as? ViewInstrumentationState {
                    return value as ViewInstrumentationState
                }

                return nil
            }

            set {
                objc_setAssociatedObject(
                    self,
                    &AssociatedKeys.anotherIdentifier,
                    newValue,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
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
