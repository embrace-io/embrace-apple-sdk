//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

    import Foundation
    import UIKit

    /// Delegate used to control which taps are allowed to be captured by a `TapCaptureService`.
    public protocol TapCaptureServiceDelegate: AnyObject {
        /// Return `false` to prevent a tap on the given view from being captured.
        func shouldCaptureTap(onView: UIView) -> Bool

        /// Return `false` to prevent the tap coordinates on the given view from being captured.
        func shouldCaptureTapCoordinates(onView: UIView) -> Bool
    }

#endif
