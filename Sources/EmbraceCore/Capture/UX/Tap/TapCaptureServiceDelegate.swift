//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

import Foundation
import UIKit

/// Delegate used to control which taps are allowed to be captured by a `TapCaptureService`.
@objc public protocol TapCaptureServiceDelegate: NSObjectProtocol {
    @objc func shouldCaptureTap(onView: UIView) -> Bool
    @objc func shouldCaptureTapCoordinates(onView: UIView) -> Bool
}

#endif
