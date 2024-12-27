//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
#if canImport(UIKit) && !os(watchOS)
import UIKit
import EmbraceCommonInternal

class ViewCaptureServiceSwizzlerCache {
    @ThreadSafe
    private var swizzledViewControllers: [UIViewController.Type]

    init(swizzledViewControllers: [UIViewController.Type] = []) {
        self.swizzledViewControllers = swizzledViewControllers
    }

    func wasViewControllerSwizzled(withType viewControllerType: UIViewController.Type) -> Bool {
        swizzledViewControllers.contains(where: { viewControllerType == $0 })
    }

    func addNewSwizzled(viewControllerType: UIViewController.Type) {
        swizzledViewControllers.append(viewControllerType)
    }
}

extension ViewCaptureServiceSwizzlerCache {
    static func withDefaults() -> ViewCaptureServiceSwizzlerCache {
        .init(swizzledViewControllers: [UIViewController.self])
    }
}

#endif
