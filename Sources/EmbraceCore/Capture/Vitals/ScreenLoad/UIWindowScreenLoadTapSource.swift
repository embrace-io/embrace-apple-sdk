//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
    import UIKit

    /// A ``ScreenLoadTapSource`` fed by the `UIWindow.sendEvent` swizzle owned by `TapCaptureService`.
    ///
    /// Reports a tap up when the last touch of a sequence ends: every touch in the event has ended. Any
    /// cancelled touch means the gesture was aborted, so it is not a tap, matching Android's `ACTION_CANCEL`.
    ///
    /// Taps are reported synchronously on the main thread, where `sendEvent` runs.
    final class UIWindowScreenLoadTapSource: ScreenLoadTapSource {

        var onTapUp: ((TimeInterval) -> Void)?

        func handle(_ event: UIEvent) {
            // a touch still down means the sequence hasn't ended, and a cancelled one aborts the gesture
            guard let onTapUp,
                event.type == .touches,
                let touches = event.allTouches,
                !touches.isEmpty,
                touches.allSatisfy({ $0.phase == .ended })
            else {
                return
            }

            onTapUp(event.timestamp)
        }
    }
#endif
