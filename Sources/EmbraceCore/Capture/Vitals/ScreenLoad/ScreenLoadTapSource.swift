//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Reports committed taps (touch up) to the screen-load tracker, keeping the tracker free of UIKit.
/// The Android equivalent is `VitalsWindowCallback`'s `ACTION_UP`.
protocol ScreenLoadTapSource: AnyObject {

    /// Called with the time of each tap up, in seconds on the system uptime base
    /// (`ProcessInfo.systemUptime`).
    ///
    /// Called on the main thread. Set it from the main thread only, as it isn't protected by a lock.
    var onTapUp: ((TimeInterval) -> Void)? { get set }
}
