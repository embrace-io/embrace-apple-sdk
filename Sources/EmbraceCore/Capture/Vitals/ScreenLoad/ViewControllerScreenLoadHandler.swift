//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
    import UIKit
    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceCommonInternal
    #endif

    /// Turns `UIViewController` lifecycle callbacks into the screen-load tracker's navigation signals, and
    /// connects the tracker to the tap and frame-displayed sources. The Android equivalent is
    /// `ActivityNavigationSource` plus the wiring in `VitalsDataSource`.
    ///
    /// - Navigation start: the start of `viewDidLoad` on an eligible view controller. Starts before the app
    ///   first becomes active are skipped, since that's the cold start, which startup measures. This is
    ///   Android's `skipNextCreate`, widened to cover every controller loaded during launch (for example a
    ///   navigation controller and its root).
    /// - Navigation end: the end of `viewIsAppearing` (iOS 17+) or `viewWillAppear` (earlier), only on a
    ///   controller whose navigation start was reported and not yet ended. Reappearances produce neither.
    ///   An override of `viewIsAppearing` that calls `super` runs every swizzled class's implementation, so
    ///   navigation end waits for the outermost one to finish.
    ///
    /// ## Threading
    /// The lifecycle callbacks, taps and frames all arrive on the main thread, so the tracker runs there
    /// too. ``start(tapSource:)`` and ``stop()`` can be called from any thread: they record the wanted
    /// state and apply the latest one on the main thread, so a stop always wins over an earlier start.
    final class ViewControllerScreenLoadHandler {

        typealias TrackerFactory = (_ emit: @escaping (ScreenLoadResult) -> Void) -> ScreenLoadTracker

        /// Whether navigation end is the end of `viewIsAppearing` rather than `viewWillAppear`.
        let usesViewIsAppearing: Bool

        private let frameSource: FrameDisplayedSource
        private let applicationState: () -> UIApplication.State
        private let uptimeProvider: () -> TimeInterval
        private let notificationCenter: NotificationCenter
        private let makeTracker: TrackerFactory

        /// Receives each completed load, on the main thread.
        var onResult: ((ScreenLoadResult) -> Void)?

        // The state `start`/`stop` asked for, applied on the main thread.
        private struct WantedState {
            var running = false
            var tapSource: ScreenLoadTapSource?
        }
        private let wanted = EmbraceMutex(WantedState())

        // Main thread only.
        private var tracker: ScreenLoadTracker?
        private var tapSource: ScreenLoadTapSource?
        private var observers: [NSObjectProtocol] = []
        private var hasBecomeActive = false

        // Bumped by each frame request, so only the latest request can complete a load. An earlier
        // request's frame can arrive before the latest navigation end's commit.
        private var frameRequestGeneration = 0

        /// - Parameters:
        ///   - frameSource: Reports the first frame after navigation end.
        ///   - usesViewIsAppearing: Whether navigation end is the end of `viewIsAppearing`.
        ///   - applicationState: The app's current state. Read on the main thread.
        ///   - uptimeProvider: The current system uptime, which navigation start and end are stamped with.
        ///   - notificationCenter: Where the app's activation and background notifications are posted.
        ///   - makeTracker: Builds the tracker on each start. Tests pass their own clocks and scheduler.
        init(
            frameSource: FrameDisplayedSource = DisplayLinkFrameDisplayedSource(),
            usesViewIsAppearing: Bool = ViewControllerScreenLoadHandler.isViewIsAppearingAvailable,
            applicationState: @escaping () -> UIApplication.State = { UIApplication.shared.applicationState },
            uptimeProvider: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
            notificationCenter: NotificationCenter = .default,
            makeTracker: @escaping TrackerFactory = { ScreenLoadTracker(queue: .main, emit: $0) }
        ) {
            self.frameSource = frameSource
            self.usesViewIsAppearing = usesViewIsAppearing
            self.applicationState = applicationState
            self.uptimeProvider = uptimeProvider
            self.notificationCenter = notificationCenter
            self.makeTracker = makeTracker
        }

        deinit {
            observers.forEach(notificationCenter.removeObserver)
        }

        static var isViewIsAppearingAvailable: Bool {
            if #available(iOS 17.0, tvOS 17.0, *) {
                return true
            }
            return false
        }

        // MARK: - Lifecycle

        /// Starts measuring screen loads, with taps from `tapSource` if there is one. Without it, every load
        /// starts at its navigation start.
        func start(tapSource: ScreenLoadTapSource?) {
            wanted.withLock {
                $0.running = true
                $0.tapSource = tapSource
            }
            applyWantedState()
        }

        /// Stops measuring, dropping any pending load and releasing the frame source.
        func stop() {
            wanted.withLock {
                $0.running = false
                $0.tapSource = nil
            }
            applyWantedState()
        }

        private func applyWantedState() {
            guard Thread.isMainThread else {
                DispatchQueue.main.async { [weak self] in
                    self?.applyWantedState()
                }
                return
            }

            let wanted = wanted.safeValue
            if wanted.running {
                if tracker == nil {
                    startOnMain()
                }
                connect(tapSource: wanted.tapSource)
            } else if tracker != nil {
                stopOnMain()
            }
        }

        private func startOnMain() {
            tracker = makeTracker { [weak self] result in
                self?.onResult?(result)
            }

            // If the app is already active, launch is over, so nothing is skipped.
            hasBecomeActive = applicationState() == .active

            observers = [
                notificationCenter.addObserver(
                    forName: UIApplication.didBecomeActiveNotification,
                    object: nil,
                    queue: nil
                ) { [weak self] _ in
                    self?.hasBecomeActive = true
                },
                notificationCenter.addObserver(
                    forName: UIApplication.didEnterBackgroundNotification,
                    object: nil,
                    queue: nil
                ) { [weak self] _ in
                    self?.tracker?.interrupt()
                }
            ]
        }

        private func stopOnMain() {
            connect(tapSource: nil)
            observers.forEach(notificationCenter.removeObserver)
            observers.removeAll()
            frameSource.stop()
            tracker?.interrupt()
            tracker = nil
        }

        private func connect(tapSource newSource: ScreenLoadTapSource?) {
            guard tapSource !== newSource else {
                return
            }

            tapSource?.onTapUp = nil
            tapSource = newSource
            tapSource?.onTapUp = { [weak self] time in
                self?.tracker?.tap(at: time)
            }
        }

        // MARK: - Navigation

        /// The start of `viewDidLoad` on an eligible view controller loading for the first time.
        func navigationStart(_ vc: UIViewController) {
            guard Thread.isMainThread, let tracker, !vc.emb_screenLoadNavigationPending else {
                return
            }

            // Cold start belongs to startup, and nothing loaded in the background is a navigation.
            guard hasBecomeActive, applicationState() != .background else {
                return
            }

            vc.emb_screenLoadNavigationPending = true
            tracker.navigationStart(name: vc.emb_viewName, at: uptimeProvider())
        }

        /// The end of `viewWillAppear`. Navigation end only before iOS 17.
        func viewWillAppearEnded(_ vc: UIViewController) {
            guard !usesViewIsAppearing else {
                return
            }
            navigationEnd(vc)
        }

        /// The start of one swizzled `viewIsAppearing` implementation. Nested when an override calls `super`.
        func viewIsAppearingStarted(_ vc: UIViewController) {
            guard usesViewIsAppearing, Thread.isMainThread, vc.emb_screenLoadNavigationPending else {
                return
            }
            vc.emb_screenLoadViewIsAppearingDepth += 1
        }

        /// The end of one swizzled `viewIsAppearing` implementation. Navigation end from iOS 17, once the
        /// outermost one ends.
        func viewIsAppearingEnded(_ vc: UIViewController) {
            guard usesViewIsAppearing, Thread.isMainThread, vc.emb_screenLoadNavigationPending else {
                return
            }

            vc.emb_screenLoadViewIsAppearingDepth -= 1
            guard vc.emb_screenLoadViewIsAppearingDepth <= 0 else {
                return
            }
            navigationEnd(vc)
        }

        private func navigationEnd(_ vc: UIViewController) {
            guard Thread.isMainThread, vc.emb_screenLoadNavigationPending else {
                return
            }
            let uptime = uptimeProvider()
            vc.emb_screenLoadNavigationPending = false
            vc.emb_screenLoadViewIsAppearingDepth = 0

            guard let tracker else {
                return
            }

            tracker.navigationEnd(name: vc.emb_viewName, at: uptime)

            frameRequestGeneration += 1
            let generation = frameRequestGeneration
            frameSource.requestNextFrame { [weak self] frameUptime in
                guard let self, generation == self.frameRequestGeneration else {
                    return
                }
                self.tracker?.frame(at: frameUptime)
            }
        }
    }
#endif
