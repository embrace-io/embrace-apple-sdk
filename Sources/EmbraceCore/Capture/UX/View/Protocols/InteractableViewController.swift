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
        public func setInteractionReady() {
            try? Embrace.client?.captureServices.onInteractionReady(for: self)
        }
    }

#endif
