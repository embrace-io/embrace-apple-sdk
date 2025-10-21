//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
#if canImport(UIKit) && !os(watchOS)
    import UIKit
    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceCommonInternal
    #endif

    class ViewCaptureServiceSwizzlerCache {

        private let swizzledViewControllers: EmbraceMutex<[UIViewController.Type]>

        init(swizzledViewControllers: [UIViewController.Type] = []) {
            self.swizzledViewControllers = EmbraceMutex(swizzledViewControllers)
        }

        func wasViewControllerSwizzled(withType viewControllerType: UIViewController.Type) -> Bool {
            swizzledViewControllers.withLock {
                $0.contains(where: { viewControllerType == $0 })
            }
        }

        func addNewSwizzled(viewControllerType: UIViewController.Type) {
            swizzledViewControllers.withLock {
                $0.append(viewControllerType)
            }
        }
    }

    extension ViewCaptureServiceSwizzlerCache {
        static func withDefaults() -> ViewCaptureServiceSwizzlerCache {
            .init(swizzledViewControllers: [UIViewController.self])
        }
    }

#endif
