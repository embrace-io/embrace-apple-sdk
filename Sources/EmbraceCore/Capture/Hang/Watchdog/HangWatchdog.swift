import Foundation
import Atomics

/// Protocol for objects that observe hang detection events.
/// Implement these methods to handle the various phases of a detected hang.
///
/// - hangStarted: Called when a hang is first detected on a background queue.
/// - hangUpdated: Called periodically while a hang persists on a background queue.
/// - hangEnded: Called when the hang ends on the hung thread.
public protocol HangObserver: AnyObject {
    func hangStarted(at nanoseconds: UInt64, duration nanoseconds: UInt64)
    func hangUpdated(at nanoseconds: UInt64, duration nanoseconds: UInt64)
    func hangEnded(at nanoseconds: UInt64, duration nanoseconds: UInt64)
}

/// A watchdog that detects and reports RunLoop hangs exceeding a specified threshold.
/// Use this class to monitor app responsiveness by receiving callbacks when
/// the monitored RunLoop is blocked beyond acceptable durations.
/// Initialize as early as possible during app launch to start monitoring.
final public class HangWatchdog {
    
    /// Default hang threshold defined by Apple (0.25 seconds).
    public static let defaultAppleHangThreshold: TimeInterval = 0.249
    
    /// The interval, in seconds, that the monitored RunLoop must be blocked
    /// before it is considered a hang.
    /// Default is 0.25 seconds (250 milliseconds).
    public let threshold: TimeInterval
    
    /// The HangObserver instance that receives callbacks for hang start,
    /// hang update, and hang end events.
    public weak var hangObserver: HangObserver? = nil
    
    /// Initializes a new HangWatchdog instance.
    /// - Parameters:
    ///   - threshold: The hang threshold in seconds.
    ///   - runLoop: The RunLoop to monitor for hangs.
    public init(threshold: TimeInterval = HangWatchdog.defaultAppleHangThreshold,
                runLoop: RunLoop = .main) {
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
    private var observer: CFRunLoopObserver? = nil
    
    // The hi-priority thread used to ping the watchdog
    // _runLoop_.
    private var watchdogThread: Thread? = nil
    
    // The RunLoop created on the watchdog thread that
    // allows us to use a timer to ping the watched _runLoop_.
    private var watchdogRunLoop: RunLoop? = nil
    
    // A timer that pings the watchdog thread while
    // we're waiting for the watched _runLoop_ to resolve
    // running all events.
    private var watchdogTimer: CFRunLoopTimer? = nil
    
    // the RunLoop we are watching for hangs.
    private let runLoop: RunLoop
    
    /// Internal structure for tracking whether a hang is active and recording
    /// the timestamp when the RunLoop was entered.
    private struct HangData {
        var hanging: ManagedAtomic<Bool> = ManagedAtomic(false)
        var enterTime: ManagedAtomic<UInt64> = ManagedAtomic(0)
    }
    private var hangData = HangData()
}

// MARK: - Private Watchdog

extension HangWatchdog {
    
    /// Sets up a dedicated high-priority thread with its own RunLoop
    /// to perform hang detection pings without blocking the monitored RunLoop.
    private func scheduleThread() {
        
        runLoopPrecondition(runloop: runLoop)
        
        let semaphore = DispatchSemaphore(value: 0)
        
        watchdogThread = Thread { [weak self] in
            let rl = RunLoop.current
            rl.add(NSMachPort(), forMode: .common)
            self?.watchdogRunLoop = rl
            semaphore.signal()
            rl.run()
        }
        watchdogThread?.name = "com.embrace.watchdog"
        watchdogThread?.threadPriority = 1.0; // 1 is the max priority.
        watchdogThread?.start()
        
        // We need to get the watchdog thread runloop,
        // so we simply wait here until it's set on
        // that thread.
        semaphore.wait()
    }
    
    /// Adds a CFRunLoopObserver to the monitored RunLoop that listens for
    /// .beforeWaiting and .afterWaiting activities to detect hang start and end events.
    private func scheduleObserver() {
        
        runLoopPrecondition(runloop: runLoop)
        
        // A hang starts when it takes more than 250ms between
        // two .beforeWaiting run loop events.
        // ref: https://developer.apple.com/documentation/xcode/understanding-hangs-in-your-app#Understand-hangs
        observer = CFRunLoopObserverCreateWithHandler(
            kCFAllocatorDefault,
            CFRunLoopActivity(arrayLiteral: [.beforeWaiting, .afterWaiting]).rawValue,
            true,
            0)
        { [weak self] _, activity in
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
                if hangData.hanging.exchange(false, ordering: .relaxed) == true {
                    
                    // update the time value
                    let now = suspendingTimeInNanoseconds()
                    let hangTime = now - hangData.enterTime.value
                    
                    // log it
                    self.hangObserver?.hangEnded(at: now, duration: hangTime)
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
        }
    }
    
    /// Schedules a CFRunLoopTimer on the watchdog thread to measure how long
    /// the monitored RunLoop remains blocked. Triggers hangObserver callbacks:
    /// hangStarted, hangUpdated, and hangEnded.
    private func schedulePings() {
        
        runLoopPrecondition(runloop: runLoop)
        
        // store the time
        let startTime = suspendingTimeInNanoseconds()
        hangData.enterTime.value = startTime
        
        let threasholdInNs = UInt64(threshold * 1_000_000_000)
        
        // Run the timer on the watchdog run loop to ping it
        // until this callback is entered again and resolves any hang.
        watchdogTimer = CFRunLoopTimerCreateWithHandler(
            kCFAllocatorDefault,
            CFAbsoluteTimeGetCurrent(),
            threshold,
            0,
            0
        ) { [weak self] timer in
            
            guard let self else { return }
            precondition(Thread.current == self.watchdogThread)
            
            let now = suspendingTimeInNanoseconds()
            let enterTime = hangData.enterTime.value
            let hangTime = now - enterTime
            let isHang = hangTime >= threasholdInNs
            
            if isHang {
                
                // Hang Start
                if self.hangData.hanging.exchange(true, ordering: .relaxed) == false {
                    self.hangObserver?.hangStarted(at: enterTime, duration: hangTime)
                }
                
                // Hang Update
                else {
                    self.hangObserver?.hangUpdated(at: now, duration: hangTime)
                }
                
                // Change the interval for the duration of the hang
                // This makes things a lot harder to grok in a flame chart !!
                // let nextFireDate = CFRunLoopTimerGetNextFireDate(timer) + (self.threshold * 1.2)
                // CFRunLoopTimerSetNextFireDate(timer, nextFireDate)
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
    precondition({
        runloop() == RunLoop.current
    }())
}

/// Returns the current uptime in nanoseconds, including system sleep time,
/// using CLOCK_UPTIME_RAW.
/// - Returns: The timestamp in nanoseconds.
private func suspendingTimeInNanoseconds() -> UInt64 {
    clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
}

fileprivate extension ManagedAtomic {
    var value: Value {
        get { self.load(ordering: .relaxed) }
        set { self.store(newValue, ordering: .relaxed) }
    }
}
