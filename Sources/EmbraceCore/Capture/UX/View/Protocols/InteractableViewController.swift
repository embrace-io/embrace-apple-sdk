//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

    import Foundation
    import UIKit

    public protocol InteractableViewController: UIViewController {

    }

    extension InteractableViewController {
        /// Call this method in your `UIViewController` when it is ready to be interacted by the user.
        /// - Throws: `ViewCaptureService.noServiceFound` if no `ViewCaptureService` is active.
        /// - Throws: `ViewCaptureService.firstRenderInstrumentationDisabled` if this functionallity was not enabled when setting up the `ViewCaptureService`, or the remote configuration for this feature was not enabled.
        public func setInteractionReady() throws {
            try Embrace.client?.captureServices.onInteractionReady(for: self)
        }
    }

#endif
