//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import UIKit

    #if DEBUG
        import os.signpost
    #endif

    /// Collects the activity that keeps a focal moment alive, for the tick handler to take once per tick:
    /// touch phases from `UIWindow.sendEvent(_:)`, the main run loop tracking a scroll, and main-thread work.
    ///
    /// Main-thread work is measured as busy time per run-loop wake, from `afterWaiting` to `beforeWaiting`,
    /// minus the tick's own handling. App animations driven by `CADisplayLink` (SwiftUI, Lottie) run in the
    /// same vsync wake as the tick, so whether a wake contained the tick can't tell them apart from an idle
    /// tick. Busy time can: an idle tick's wake only costs the display link's dispatch and an empty commit.
    /// Work done in the tick's wake before the tick is credited to that tick; work after it, to the next.
    ///
    /// Everything runs on main.
    final class ActivityMonitor {

        struct Snapshot: Equatable {
            /// A touch went down since the previous tick.
            var touchBegan = false

            /// Any touch phase was seen since the previous tick.
            var touchChanged = false

            /// Touches down as of the latest touch event.
            var activeTouchCount = 0

            /// The main run loop is tracking a scroll, deceleration included.
            var isTracking = false

            /// The main thread did more than `workThreshold` of work, other than the tick's own handling,
            /// since the previous tick.
            var didWork = false

            var hasActivity: Bool {
                touchChanged || isTracking || didWork
            }
        }

        /// Busy time per wake at or below this is the cost of servicing the display link, not work.
        /// Provisional until device measurements set it.
        static let defaultWorkThreshold: TimeInterval = 0.000_2

        /// - Parameters:
        ///   - runLoop: The run loop whose wakes are measured. Tests pass `nil` and drive wakes through
        ///     `runLoopDidWake()` / `runLoopWillSleep()`.
        ///   - clock: Monotonic nanoseconds.
        ///   - environment: In debug builds, `EMBSmoothnessSignposts=1` emits an `os_signpost` event
        ///     (subsystem `io.embrace.sdk`, category `Smoothness`, name `Busy`) with each measured busy
        ///     time in nanoseconds, for tuning `workThreshold` in Instruments.
        init(
            windowEventObserver: WindowEventObserver = .shared,
            runLoop: CFRunLoop? = CFRunLoopGetMain(),
            currentMode: @escaping () -> RunLoop.Mode? = ActivityMonitor.mainRunLoopMode,
            clock: @escaping () -> UInt64 = { clock_gettime_nsec_np(CLOCK_UPTIME_RAW) },
            workThreshold: TimeInterval = ActivityMonitor.defaultWorkThreshold,
            environment: [String: String] = ProcessInfo.processInfo.environment
        ) {
            self.windowEventObserver = windowEventObserver
            self.runLoop = runLoop
            self.currentMode = currentMode
            self.clock = clock
            self.workThresholdNanos = UInt64(max(0, workThreshold) * 1_000_000_000)

            #if DEBUG
                if environment["EMBSmoothnessSignposts"] == "1" {
                    signpostLog = OSLog(subsystem: "io.embrace.sdk", category: "Smoothness")
                }
            #endif
        }

        deinit {
            stop()
        }

        /// Starts observing touches and run-loop wakes. Must be called on main.
        ///
        /// - Throws: If the `sendEvent` swizzle can't be installed. Nothing is observed.
        func start() throws {
            guard token == nil else { return }

            token = try windowEventObserver.add { [weak self] event in
                self?.handle(event)
            }

            guard let runLoop else { return }

            // Wake first and sleep last, so the measured busy time includes every other observer, the
            // Core Animation commit among them.
            let wake = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, CFRunLoopActivity.afterWaiting.rawValue, true, .min) {
                [weak self] _, _ in self?.runLoopDidWake()
            }
            let sleep = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, CFRunLoopActivity.beforeWaiting.rawValue, true, .max) {
                [weak self] _, _ in self?.runLoopWillSleep()
            }
            observers = [wake, sleep].compactMap { $0 }
            for observer in observers {
                CFRunLoopAddObserver(runLoop, observer, .commonModes)
            }
        }

        /// Must be called on main.
        func stop() {
            for observer in observers {
                CFRunLoopObserverInvalidate(observer)
            }
            observers = []

            if let token {
                windowEventObserver.remove(token)
                self.token = nil
            }

            pending = Snapshot()
            wakeStart = nil
        }

        /// Takes the activity since the previous tick, then runs the tick's handling, whose time isn't
        /// counted as work. Must be called on main.
        func tick<T>(_ body: (Snapshot) -> T) -> T {
            let now = clock()
            if let start = wakeStart {
                recordBusy(now > start ? now - start : 0)
                wakeStart = now
            }

            var snapshot = pending
            snapshot.isTracking = currentMode() == .tracking
            pending = Snapshot(activeTouchCount: pending.activeTouchCount)

            let result = body(snapshot)

            if wakeStart != nil {
                wakeStart = clock()
            }
            return result
        }

        // MARK: - Internal

        static func mainRunLoopMode() -> RunLoop.Mode? {
            guard let mode = CFRunLoopCopyCurrentMode(CFRunLoopGetMain()) else { return nil }
            return RunLoop.Mode(mode.rawValue as String)
        }

        func handle(_ event: UIEvent) {
            guard event.type == .touches, let touches = event.allTouches else { return }

            // Recounted on every event, so a missed end corrects itself on the next one.
            var active = 0
            for touch in touches {
                switch touch.phase {
                case .began:
                    pending.touchBegan = true
                    active += 1
                case .ended, .cancelled:
                    break
                default:
                    active += 1
                }
            }
            pending.touchChanged = true
            pending.activeTouchCount = active
        }

        func runLoopDidWake() {
            wakeStart = clock()
        }

        func runLoopWillSleep() {
            guard let start = wakeStart else { return }
            let now = clock()
            recordBusy(now > start ? now - start : 0)
            wakeStart = nil
        }

        // MARK: - Private

        private let windowEventObserver: WindowEventObserver
        private let runLoop: CFRunLoop?
        private let currentMode: () -> RunLoop.Mode?
        private let clock: () -> UInt64
        private let workThresholdNanos: UInt64

        private var token: WindowEventObserver.Token?
        private var observers: [CFRunLoopObserver] = []

        private var pending = Snapshot()

        /// When the current wake's unmeasured busy time began, or `nil` while the run loop sleeps.
        private var wakeStart: UInt64?

        #if DEBUG
            private var signpostLog: OSLog?
        #endif

        private func recordBusy(_ nanos: UInt64) {
            #if DEBUG
                if let signpostLog {
                    os_signpost(.event, log: signpostLog, name: "Busy", "%{public}llu", nanos)
                }
            #endif

            if nanos > workThresholdNanos {
                pending.didWork = true
            }
        }
    }

#endif  // !os(watchOS) && !os(macOS)
