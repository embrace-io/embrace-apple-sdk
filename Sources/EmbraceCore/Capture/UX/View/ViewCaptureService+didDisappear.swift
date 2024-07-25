//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit)

import UIKit
import EmbraceCommonInternal
import EmbraceOTelInternal

extension ViewCaptureService {
    func handleViewDidDisappear(_ vc: UIViewController, animated: Bool) {
        guard state == .active else {
            return
        }

        guard vc.embCaptureView else {
            Embrace.logger.debug("\(vc.description) View is manually ignored")
            return
        }

        guard let span = vc.emb_associatedSpan else {
            Embrace.logger.error("\(vc.description) Can not be closed because it's not being tracked")
            return
        }

        span.end()
        vc.emb_associatedSpan = nil
    }
}

class UIViewControllerDidDisappearSwizzler: Swizzlable {
    typealias ImplementationType = @convention(c) (UIViewController, Selector, Bool) -> Void
    typealias BlockImplementationType = @convention(block) (UIViewController, Bool) -> Void
    static var selector: Selector = #selector(
        UIViewController.viewDidDisappear(_:)
    )

    var baseClass: AnyClass = UIViewController.self

    var onViewDidDisappear: ((UIViewController, Bool) -> Void)?

    func install() throws {
        try swizzleInstanceMethod { originalImplementation in
            return { [weak self] viewController, animated -> Void in
                self?.onViewDidDisappear?(viewController, animated)
                originalImplementation(viewController, UIWindowSendEventSwizzler.selector, animated)
            }
        }
    }
}

#endif
