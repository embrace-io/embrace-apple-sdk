//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

    import UIKit

    /// Reports app-wide touch activity, independent of any specific view or view controller.
    ///
    /// `TouchActivitySource` swizzles `UIWindow.sendEvent` once and fires `onTouch` whenever a
    /// touch is delivered anywhere in the app. It draws no distinction between one view and the
    /// next, and applies no debouncing of its own — it exists only to answer "is the user
    /// currently interacting with the screen," which is what `FocalMomentTracker` needs to open
    /// or extend a focal moment.
    final class TouchActivitySource {

        /// Called on the main thread whenever a touch is delivered anywhere in the app.
        var onTouch: (() -> Void)?

        private var swizzler: UIWindowSendEventSwizzler?

        /// Creates a new `TouchActivitySource` and immediately begins observing touch activity.
        ///
        /// Must be called on the main thread.
        init() {
            do {
                let swizzler = UIWindowSendEventSwizzler()
                swizzler.onEvent = { [weak self] event in
                    self?.handle(event)
                }
                try swizzler.install()
                self.swizzler = swizzler
            } catch let exception {
                Embrace.logger.error(
                    "An error occurred while swizzling UIWindow.sendEvent for touch-activity: \(exception.localizedDescription)"
                )
            }
        }

        private func handle(_ event: UIEvent) {
            guard event.type == .touches,
                let touches = event.allTouches,
                !touches.isEmpty
            else {
                return
            }

            onTouch?()
        }
    }

#endif  // canImport(UIKit) && !os(watchOS)
