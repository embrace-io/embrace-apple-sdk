//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
#if canImport(UIKit)
import UIKit
import SwiftUI
import EmbraceCaptureService
import EmbraceCommon
import EmbraceOTel

@objc public final class ViewCaptureService: CaptureService {
    private var didAppearSwizzle: UIViewControllerDidAppearSwizzler?
    private var didDisappearSwizzle: UIViewControllerDidDisappearSwizzler?
    private var lock: UnfairLock

    public override init() {
        self.lock = UnfairLock()
    }

    override public func onInstall() {
        lock.locked {
            guard state == .uninstalled else {
                return
            }

            do {
                didAppearSwizzle = UIViewControllerDidAppearSwizzler()
                didDisappearSwizzle = UIViewControllerDidDisappearSwizzler()

                didAppearSwizzle?.onViewDidAppear = { [weak self] viewController, animated in
                    self?.handleViewDidAppear(viewController, animated: animated)
                }

                didDisappearSwizzle?.onViewDidDisappear = { [weak self] viewController, animated in
                    self?.handleViewDidDisappear(viewController, animated: animated)
                }

                try didAppearSwizzle?.install()
                try didDisappearSwizzle?.install()
            } catch let exception {
                Embrace.logger.error("An error ocurred while swizzling UIViewController: \(exception.localizedDescription)")
            }
        }
    }
}

#endif
