import Foundation
import Atomics
import OpenTelemetryApi

/// HangWatchdog is a class that will help you discover
/// hangs within your application. Create one very early
/// during ap launch and add observers in order to be notified
/// of issues.
final public class HangWatchdog {
    
    /// Default threashold defined by Apple (250ms).
    public static let defaultAppleHangThreshold: TimeInterval = 0.249
    
    /// Interval in seconds the main queue should be
    /// held up before calling it a Hang.
    /// 250ms is the standard.
    public let threshold: TimeInterval
    
    /// Initialize a new watchdog with a hang threshold.
    public init(threshold: TimeInterval = HangWatchdog.defaultAppleHangThreshold) {
        self.threshold = threshold
        self.runWatchdogThread()
        self.runObserver()
    }
    
    deinit {
        if let observer {
            CFRunLoopRemoveObserver(runLoop.getCFRunLoop(), observer, .commonModes)
        }
        if let watchdogTimer {
            CFRunLoopTimerInvalidate(watchdogTimer)
        }
        if let watchdogRunLoop {
            CFRunLoopStop(watchdogRunLoop.getCFRunLoop())
        }
        self.watchdogThread?.cancel()
    }
    
    /// Private.
    private var observer: CFRunLoopObserver? = nil
    private var watchdogThread: Thread? = nil
    private let runLoop: RunLoop = RunLoop.main
    private var watchdogRunLoop: RunLoop? = nil
    private var watchdogTimer: CFRunLoopTimer? = nil

    private struct HangData {
        var hanging: ManagedAtomic<Bool> = ManagedAtomic(false)
        var span: OpenTelemetryApi.Span? = nil
        var enterTime: ManagedAtomic<UInt64> = ManagedAtomic(0)
        var totalTime: ManagedAtomic<UInt64> = ManagedAtomic(0)
    }
    private var hangData = HangData()
}

// MARK: - Private Watchdog

extension HangWatchdog {
    
    // setup a hipri thread with a run loop
    // to simplify message passing and adding
    // a timer to check for hangs.
    private func runWatchdogThread() {
        
        dispatchPrecondition(condition: .onQueue(.main))
        
        self.watchdogThread = Thread { [weak self] in
            let rl = RunLoop.current
            rl.add(NSMachPort(), forMode: .common)
            DispatchQueue.main.sync {
                self?.watchdogRunLoop = rl
            }
            rl.run()
        }
        self.watchdogThread?.name = "com.embrace.watchdog"
        self.watchdogThread?.threadPriority = 1.0;
        self.watchdogThread?.start()
        
    }
    
    // Observe the time it takes to wait on events
    // on the run loop.
    private func runObserver() {
        
        dispatchPrecondition(condition: .onQueue(.main))
        
        // A hang starts when it takes more than 250ms between
        // two .beforeWaiting run loop events on the main queue.
        // ref: https://developer.apple.com/documentation/xcode/understanding-hangs-in-your-app#Understand-hangs
        self.observer = CFRunLoopObserverCreateWithHandler(
            kCFAllocatorDefault,
            CFRunLoopActivity(arrayLiteral: [.beforeWaiting, .afterWaiting]).rawValue,
            true,
            CFIndex.max)
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
                    hangData.totalTime.value = ns() - hangData.enterTime.value
                    
                    // send a span completion
                    hangData.span?.end()
                    hangData.span = nil
                    
                    // log it
                    print("[AC:Watchdog] Hang ended at \(Double(hangData.totalTime.value)/1_000_000_000.0) s")
                }
                
            }
            
            // After waiting, we start processing events.
            // This means we need to watch for hangs in
            // this period.
            else if activity == .afterWaiting {
                self.runWatchdogPings()
            }

        }
        if let obs = self.observer {
            CFRunLoopAddObserver(runLoop.getCFRunLoop(), obs, .commonModes)
        }
    }
    
    // Ping the watchdog thread every N ms in order to check
    // if we're in a hang or not. If we are, run the correct callbacks.
    private func runWatchdogPings() {
        
        dispatchPrecondition(condition: .onQueue(.main))
        
        // store the time
        let startTime = ns()
        hangData.enterTime.value = startTime
        hangData.totalTime.value = 0
        
        let threasholdInNs = UInt64(threshold * 1_000_000_000)
        
        // Run the timer on the watchdog run loop to ping the main queue
        // until this callback is entered again and resolves any hang.
        self.watchdogTimer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, CFAbsoluteTimeGetCurrent(), threshold, 0, CFIndex.max) { [weak self] timer in
            
            guard let self else { return }
            precondition(Thread.current == self.watchdogThread)
            
            let now = ns()
            let hangTime = now - hangData.enterTime.value
            
            self.hangData.totalTime.value = hangTime
            let isHang = hangTime >= threasholdInNs
            
            if isHang {
                
                // do we need to flag the start of a hang ??
                if self.hangData.hanging.exchange(true, ordering: .relaxed) == false {
                    hangData.span = Embrace.client!.buildSpan(name: "Hang").startSpan()
                    print("[AC:Watchdog] Hang started at \(Double(hangTime)/1_000_000.0) ms")
                } else {
                    hangData.span?.addEvent(name: "hang.ping")
                    print("[AC:Watchdog] Hang for \(Double(hangData.totalTime.value)/1_000_000_000.0) s")
                }
                
                // Change the interval for the duration of the hang
                // This makes things a lot harder to grok in a flame chart !!
                // let nextFireDate = CFRunLoopTimerGetNextFireDate(timer) + (self.threshold * 1.2)
                // CFRunLoopTimerSetNextFireDate(timer, nextFireDate)
            }
        }
        if let timer = self.watchdogTimer {
            CFRunLoopAddTimer(watchdogRunLoop?.getCFRunLoop(), timer, .commonModes)
        }
    }
}

// MARK: - Private Helpers

private func ns() -> UInt64 {
    clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
}

fileprivate extension ManagedAtomic where Value: AtomicInteger {
    static func += (lhs: ManagedAtomic<Value>, rhs: Value) {
        lhs.add(rhs)
    }
    
    func add(_ value: Value) {
        self.wrappingIncrement(by: value, ordering: .relaxed)
    }
}

fileprivate extension ManagedAtomic {
    var value: Value {
        get { self.load(ordering: .relaxed) }
        set { self.store(newValue, ordering: .relaxed) }
    }
}
