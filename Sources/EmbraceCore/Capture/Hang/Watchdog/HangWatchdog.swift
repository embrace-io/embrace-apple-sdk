//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

/// Protocol for objects that observe hang detection events.
/// Implement these methods to handle the various phases of a detected hang.
///
/// - hangStarted: Called when a hang is first detected on a background queue.
/// - hangUpdated: Called periodically while a hang persists on a background queue.
/// - hangEnded: Called when the hang ends on the hung thread.
public protocol HangObserver: AnyObject {
    func hangStarted(at: EmbraceClock, duration: EmbraceClock)
    func hangUpdated(at: EmbraceClock, duration: EmbraceClock)
    func hangEnded(at: EmbraceClock, duration: EmbraceClock)
}

/// A watchdog that detects and reports RunLoop hangs exceeding a specified threshold.
/// Use this class to monitor app responsiveness by receiving callbacks when
/// the monitored RunLoop is blocked beyond acceptable durations.
/// Initialize as early as possible during app launch to start monitoring.
final public class HangWatchdog: @unchecked Sendable {

    /// Default hang threshold defined by Apple (0.25 seconds).
    public static let defaultAppleHangThreshold: TimeInterval = 0.249

    /// The interval, in seconds, that the monitored RunLoop must be blocked
    /// before it is considered a hang.
    /// Default is 0.25 seconds (250 milliseconds).
    public let threshold: TimeInterval

    /// The HangObserver instance that receives callbacks for hang start,
    /// hang update, and hang end events.
    public weak var hangObserver: HangObserver? {
        set { hangData.withLock { $0.hangObserver = newValue } }
        get { hangData.withLock { $0.hangObserver } }
    }

    /// Returns true if we're currently in a hang.
    public var inHang: Bool {
        hangData.withLock { $0.hanging }
    }

    /// The time in nanoseconds since the start of the hang.
    /// 0 if not in a hang.
    public var timeSinceHangStart: EmbraceClock? {
        hangData.withLock {
            guard $0.hanging else {
                return nil
            }
            return .current - $0.enterTime
        }
    }

    /// Initializes a new HangWatchdog instance.
    /// - Parameters:
    ///   - threshold: The hang threshold in seconds.
    ///   - runLoop: The RunLoop to monitor for hangs.
    public init(
        threshold: TimeInterval = HangWatchdog.defaultAppleHangThreshold,
        runLoop: RunLoop = .main
    ) {
        self.threshold = threshold
        self.runLoop = runLoop
        self.hangObserver = nil
        self.scheduleThread()
        self.scheduleObserver()
    }

    deinit {
        if let observer {
            CFRunLoopRemoveObserver(runLoop.getCFRunLoop(), observer, .commonModes)
        }
        if let watchdogTimer {
            CFRunLoopTimerInvalidate(watchdogTimer)
        }
        if let watchdogRunLoop {
            // This will stop the runloop and effectively
            // exit the _watchdogThread_.
            CFRunLoopStop(watchdogRunLoop.getCFRunLoop())
        }
        if let watchdogThread {
            // This effectively does nothing.
            // We're not checking for it anywhere.
            // But I like to be complete and have
            // this here for if we ever decide to
            // do anything special.
            watchdogThread.cancel()

            // Here we should really join the watchdogThread.
            // There's no way to do that from a `Thread`.
            // We could use a semaphore and wait to be signaled
            // from the thread exit but at this point it's
            // unlikely to be useful.
        }
    }

    /// Private.

    // The RunLoop observer that receives activities
    // and flag the timings between events.
    private var observer: CFRunLoopObserver?

    // The hi-priority thread used to ping the watchdog
    // _runLoop_.
    private var watchdogThread: Thread?

    // The RunLoop created on the watchdog thread that
    // allows us to use a timer to ping the watched _runLoop_.
    private var watchdogRunLoop: RunLoop?

    // A timer that pings the watchdog thread while
    // we're waiting for the watched _runLoop_ to resolve
    // running all events.
    private var watchdogTimer: CFRunLoopTimer?

    // the RunLoop we are watching for hangs.
    private let runLoop: RunLoop

    // Logger
    internal var logger: InternalLogger?

    /// Internal structure for tracking whether a hang is active and recording
    /// the timestamp when the RunLoop was entered.
    private struct HangData {
        var hanging: Bool = false
        var enterTime: EmbraceClock = .current
        weak var hangObserver: HangObserver?
    }
    private var hangData = EmbraceMutex(HangData())
}

// MARK: - Private Watchdog

extension HangWatchdog {

    private func _logInfo(_ msg: String) {
        if let logger {
            logger.info(msg)
        } else {
            print(msg)
        }
    }

    /// Sets up a dedicated high-priority thread with its own RunLoop
    /// to perform hang detection pings without blocking the monitored RunLoop.
    private func scheduleThread() {

        runLoopPrecondition(runloop: runLoop)

        _logInfo("[Watchdog] schedule thread")

        let semaphore = DispatchSemaphore(value: 0)

        watchdogThread = Thread { [weak self] in
            let rl = RunLoop.current
            rl.add(NSMachPort(), forMode: .common)
            self?.watchdogRunLoop = rl
            semaphore.signal()
            rl.run()
        }
        watchdogThread?.name = "com.embrace.watchdog"
        watchdogThread?.threadPriority = 1.0  // 1 is the max priority.
        watchdogThread?.start()

        // We need to get the watchdog thread runloop,
        // so we simply wait here until it's set on
        // that thread.
        semaphore.wait()

        _logInfo("[Watchdog] thread is a-go")

        // Start out by scheduling pings to make sure we catch
        // anything that happens before any run loops are running (startup).
        _logInfo("[Watchdog] schedule first ping")
        schedulePings()
    }

    /// Adds a CFRunLoopObserver to the monitored RunLoop that listens for
    /// .beforeWaiting and .afterWaiting activities to detect hang start and end events.
    private func scheduleObserver() {

        runLoopPrecondition(runloop: runLoop)

        _logInfo("[Watchdog] schedule observers")

        // A hang starts when it takes more than 250ms between
        // two .beforeWaiting run loop events.
        // ref: https://developer.apple.com/documentation/xcode/understanding-hangs-in-your-app#Understand-hangs
        observer = CFRunLoopObserverCreateWithHandler(
            kCFAllocatorDefault,
            CFRunLoopActivity(arrayLiteral: [.beforeWaiting, .afterWaiting]).rawValue,
            true,
            0
        ) { [weak self] _, activity in
            guard let self else { return }

            // kill the timer
            if let timer = self.watchdogTimer {
                CFRunLoopTimerInvalidate(timer)
                self.watchdogTimer = nil
            }

            // before the wait period, we want to check if the previous
            // cycle took more time than it should have and flag it.
            if activity == .beforeWaiting {

                // check for a hang that needs to end
                let (observer, now, hangTime): (HangObserver?, EmbraceClock?, EmbraceClock?) = hangData.withLock {
                    guard $0.hanging else {
                        return (nil, nil, nil)
                    }
                    $0.hanging = false

                    // update the time value
                    let now: EmbraceClock = .current
                    let hangTime = now - $0.enterTime

                    return ($0.hangObserver, now, hangTime)
                }

                // log it if needed
                if let observer, let now, let hangTime {
                    observer.hangEnded(at: now, duration: hangTime)
                }
            }

            // After waiting, we start processing events.
            // This means we need to watch for hangs in
            // this period.
            else if activity == .afterWaiting {
                self.schedulePings()
            }

        }
        if let obs = observer {
            CFRunLoopAddObserver(runLoop.getCFRunLoop(), obs, .commonModes)
            _logInfo("[Watchdog] observers are a-go")
        }
    }

    /// Schedules a CFRunLoopTimer on the watchdog thread to measure how long
    /// the monitored RunLoop remains blocked. Triggers hangObserver callbacks:
    /// hangStarted, hangUpdated, and hangEnded.
    private func schedulePings() {

        runLoopPrecondition(runloop: runLoop)

        // store the time
        let startTime: EmbraceClock = .current
        hangData.withLock { $0.enterTime = startTime }

        let threasholdInNs = UInt64(threshold * 1_000_000_000)

        // Run the timer on the watchdog run loop to ping it
        // until this callback is entered again and resolves any hang.
        watchdogTimer = CFRunLoopTimerCreateWithHandler(
            kCFAllocatorDefault,
            CFAbsoluteTimeGetCurrent(),
            threshold,
            0,
            0
        ) { [weak self] _ in

            guard let self else { return }
            precondition(Thread.current == self.watchdogThread)

            let now: EmbraceClock = .current
            let (observer, startHang, enterTime, hangTime) = hangData.withLock {
                let enterTime = $0.enterTime
                let hangTime = now - enterTime

                // Hangtime is based on uptime, we don't count the time the app is suspended.
                let isHang = hangTime.uptime.nanosecondsValue >= threasholdInNs

                let startHang = isHang && $0.hanging == false
                if startHang { $0.hanging = true }

                return (isHang ? $0.hangObserver : nil, startHang, enterTime, hangTime)
            }

            if let observer {

                // Hang Start
                if startHang {
                    observer.hangStarted(at: enterTime, duration: hangTime)
                }

                // Always send a hang update. If the hang just started, then we simply
                // sent a delayed start, so now send the update so the receiver
                // can do whatever they also do on update, such as take a backtrace.

                // Hang Update
                observer.hangUpdated(at: now, duration: hangTime)
            }
        }
        if let timer = watchdogTimer {
            CFRunLoopAddTimer(watchdogRunLoop?.getCFRunLoop(), timer, .commonModes)
        }
    }
}

// MARK: - Private Helpers

/// Ensures that the provided RunLoop matches the current thread’s RunLoop.
/// - Parameter runloop: The RunLoop expected to be current.
public func runLoopPrecondition(runloop: @autoclosure () -> RunLoop) {
    precondition(
        {
            runloop() == RunLoop.current
        }())
}
