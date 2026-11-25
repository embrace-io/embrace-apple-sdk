//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
    import Foundation
    import UIKit

    extension UIViewController {
        private struct AssociatedKeys {
            static var embraceIdentifier: Int = 0
            static var anotherIdentifier: Int = 1
            static var screenLoadNavigationPending: Int = 2
            static var screenLoadViewIsAppearingDepth: Int = 3
        }

        var emb_instrumentation_state: ViewInstrumentationState? {
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

        /// Whether this controller's navigation start was reported to the screen-load tracker and its
        /// navigation end wasn't yet.
        var emb_screenLoadNavigationPending: Bool {
            get {
                (objc_getAssociatedObject(self, &AssociatedKeys.screenLoadNavigationPending) as? Bool) ?? false
            }
            set {
                objc_setAssociatedObject(
                    self,
                    &AssociatedKeys.screenLoadNavigationPending,
                    newValue ? true : nil,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
            }
        }

        /// How many swizzled `viewIsAppearing` implementations are running for a pending screen load.
        var emb_screenLoadViewIsAppearingDepth: Int {
            get {
                (objc_getAssociatedObject(self, &AssociatedKeys.screenLoadViewIsAppearingDepth) as? Int) ?? 0
            }
            set {
                objc_setAssociatedObject(
                    self,
                    &AssociatedKeys.screenLoadViewIsAppearingDepth,
                    newValue > 0 ? newValue : nil,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
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

        #if !targetEnvironment(macCatalyst)
            var className: String {
                return String(describing: type(of: self))
            }
        #endif

    }
#endif
