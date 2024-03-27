//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit)
import UIKit
import EmbraceCommon
import EmbraceOTel

extension ViewCaptureService {
    func handleViewDidAppear(_ vc: UIViewController, animated: Bool) {
        guard state == .active else {
            return
        }

        guard vc.embCaptureView else {
            ConsoleLog.debug("\(vc.description) View is manually ignored")
            return
        }

        guard vc.emb_associatedSpan == nil else {
            ConsoleLog.debug("\(vc.description) Is already being tracked")
            return
        }

        let title = vc.embViewName
        let className = SwiftDemangler.demangleClassName(String(describing: vc.self))

        vc.emb_associatedSpan = otel?.buildSpan(
            name: "emb-screen-view",
            type: .view,
            attributes: ["view.title": title,
                         "view.name": className])
        .startSpan()
    }
}

class UIViewControllerDidAppearSwizzler: Swizzlable {
    typealias ImplementationType = @convention(c) (UIViewController, Selector, Bool) -> Void
    typealias BlockImplementationType = @convention(block) (UIViewController, Bool) -> Void
    static var selector: Selector = #selector(
        UIViewController.viewDidAppear(_:)
    )

    var baseClass: AnyClass = UIViewController.self

    var onViewDidAppear: ((UIViewController, Bool) -> Void)?

    func install() throws {
        try swizzleInstanceMethod { originalImplementation in
            return { [weak self] viewController, animated -> Void in
                self?.onViewDidAppear?(viewController, animated)
                originalImplementation(viewController, UIWindowSendEventSwizzler.selector, animated)
            }
        }
    }
}

#endif
