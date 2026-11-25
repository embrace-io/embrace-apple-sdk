//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation
    import QuartzCore

    /// Receives `CADisplayLink` callbacks forwarded by a ``WeakDisplayLinkProxy``.
    protocol DisplayLinkTickTarget: AnyObject {
        func displayLinkDidTick(_ link: CADisplayLink)
    }

    /// Holds a weak reference to its target to break the retain cycle that `CADisplayLink` would
    /// otherwise form with it. Use the proxy as the display link's target, with `tick(_:)` as the selector.
    final class WeakDisplayLinkProxy: NSObject {
        weak var target: DisplayLinkTickTarget?

        @objc func tick(_ link: CADisplayLink) {
            target?.displayLinkDidTick(link)
        }
    }

#endif  // !os(watchOS) && !os(macOS)
