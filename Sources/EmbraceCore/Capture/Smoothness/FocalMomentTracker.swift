//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation

    /// Tracks focal moments from the ticks it is fed. A placeholder until the state machine lands; it is
    /// not wired into the capture yet.
    class FocalMomentTracker {

        func record(_ tick: MeasuredTick) {}
    }

#endif  // !os(watchOS) && !os(macOS)
