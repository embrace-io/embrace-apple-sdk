//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

/// Protocol for objects that observe hang detection events.
///
/// - `hangStarted`: Called when a hang is first detected.
/// - `hangUpdated`: Called periodically while a hang persists (not used by `FrameRateMonitor`).
/// - `hangEnded`: Called when the hang resolves.
public protocol HangObserver: AnyObject {
    func hangStarted(at: EmbraceClock, duration: EmbraceClock)
    func hangUpdated(at: EmbraceClock, duration: EmbraceClock)
    func hangEnded(at: EmbraceClock, duration: EmbraceClock)
}
