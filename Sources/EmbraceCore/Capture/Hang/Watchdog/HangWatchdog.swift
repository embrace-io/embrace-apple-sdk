import Foundation
import Atomics

public protocol HangObserver: AnyObject {
    func hangStarted(at nanoseconds: UInt64, duration nanoseconds: UInt64)
    func hangUpdated(at nanoseconds: UInt64, duration nanoseconds: UInt64)
    func hangEnded(at nanoseconds: UInt64, duration nanoseconds: UInt64)
}

/// HangWatchdog is a class that will help you discover
/// hangs within your application. Create one very early
/// during ap launch and add observers in order to be notified
/// of issues.
final public class HangWatchdog {
    
    /// Default threashold defined by Apple (250ms).
    public static let defaultAppleHangThreshold: TimeInterval = 0.249
    
    /// Interval in seconds the RunLoop should be
    /// held up before calling it a Hang.
    /// 250ms is the standard (0.25 TimeInterval)
    public let threshold: TimeInterval
    
    /// Observer that will receive hang events
    public weak var hangObserver: HangObserver? = nil
    
    /// Initialize a new watchdog with a hang threshold and runLoop.
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
    
    // When a hang occurs, this is where we keep the data.
    private struct HangData {
        var hanging: ManagedAtomic<Bool> = ManagedAtomic(false)
        var enterTime: ManagedAtomic<UInt64> = ManagedAtomic(0)
    }
    private var hangData = HangData()
}

// MARK: - Private Watchdog

extension HangWatchdog {
    
    // setup a hipri thread with a run loop
    // to simplify message passing and adding
    // a timer to check for hangs.
    // NOTE: This will wait on the called thread (main)
    // until the new threads run loop is set.
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
    
    // Observe the time it takes to wait on events
    // on the run loop.
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
    
    // Ping the watchdog thread every N ms in order to check
    // if we're in a hang or not. If we are, run the correct callbacks.
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

public func runLoopPrecondition(runloop: @autoclosure () -> RunLoop) {
    precondition({
        runloop() == RunLoop.current
    }())
}

private func suspendingTimeInNanoseconds() -> UInt64 {
    clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
}

fileprivate extension ManagedAtomic {
    var value: Value {
        get { self.load(ordering: .relaxed) }
        set { self.store(newValue, ordering: .relaxed) }
    }
}
