import Foundation
import QuartzCore
import EmbraceCommonInternal

public func preconditionOnRunLoop(_ runLoop: @autoclosure () -> RunLoop) {
    precondition({
        runLoop() == RunLoop.current
    }())
}

// Interesting conversation on why this exists is here:
// https://iosdevelopers.slack.com/archives/C031X84F6/p1746126582968299
// Usually, we'd simply `DispatchQueue.main.async{}`, `RunLoop.main.perform{}`
// or something similar, but that can run on the same cycle
// of the RunLoop which is what we specifically don't want. We want to run
// on the _NEXT_ cycle of the run loop. __ That's what all this is for. __
//
// This tracks the cycles of the runloop for a specific mode and callsout
// to blocks that have been enqueued to run on specific cycles.
final public class RunLoopTracker {
    
    public let runLoop: RunLoop
    public let mode: RunLoop.Mode
    
    static public let main = RunLoopTracker(runLoop: .main)
    
    private init(runLoop: RunLoop, mode: RunLoop.Mode = .common) {
        self.runLoop = runLoop
        self.mode = mode
        self.setupRunLoopObservers()
    }
    
    private func setupRunLoopObservers() {
        
        // Min Observer is where we collect cycle information
        // it should be first to get callbacks dur to the priority
        // of CFIndex.min
        minObserver = CFRunLoopObserverCreateWithHandler(
            kCFAllocatorDefault,
            CFRunLoopActivity.allActivities.rawValue,
            true,
            CFIndex.min
        ) { [weak self] _, activity in
            guard let self else { return }
            
            // update state
            lock.locked {
                self.cycle.lastActivity = activity
                self.cycle[activity] += 1
            }
            //print("[RLT] min loop: \(self.debugCycleString)")
        }
        
        // Max Observer is where we collect all the blocks
        // to be run and run them. It should run last due to
        // priority. CFIndex.max
        maxObserver = CFRunLoopObserverCreateWithHandler(
            kCFAllocatorDefault,
            CFRunLoopActivity.allActivities.rawValue,
            true,
            CFIndex.max
        ) { [weak self] _, activity in
            guard let self else { return }
            
            // update state
            let blocks = lock.locked {
                // gather blocks
                let cycleValue = self.cycle[activity]
                let activityBlocks = self.activityBlockMap[activity.rawValue, default: []]
                    .filter { $0.cycle <= cycleValue }
                
                // remove them
                self.activityBlockMap[activity.rawValue]?.removeAll { $0.cycle <= cycleValue }
                return activityBlocks
            }
            
            // send them
            for blk in blocks {
                blk.block()
            }
            
            //print("[RLT] max loop: \(self.debugCycleString)")
        }
        
        lock.locked {
            if let observer = minObserver {
                CFRunLoopAddObserver(runLoop.getCFRunLoop(), observer, CFRunLoopMode(mode.rawValue as CFString))
            }
            if let observer = maxObserver {
                CFRunLoopAddObserver(runLoop.getCFRunLoop(), observer, CFRunLoopMode(mode.rawValue as CFString))
            }
        }
    }
    
    deinit {
        lock.locked {
            if let observer = minObserver {
                CFRunLoopRemoveObserver(runLoop.getCFRunLoop(), observer, CFRunLoopMode(mode.rawValue as CFString))
            }
            if let observer = maxObserver {
                CFRunLoopRemoveObserver(runLoop.getCFRunLoop(), observer, CFRunLoopMode(mode.rawValue as CFString))
            }
        }
    }
    
    // Everything private is under lock
    private let lock: UnfairLock = UnfairLock()
    
    // the observer used to track cycles
    private var minObserver: CFRunLoopObserver?
    private var maxObserver: CFRunLoopObserver?
    
    // Block that might be performed on a specific cycle
    private struct ActivityBlock {
        let block: () -> Void
        let cycle: UInt64
    }
    private var activityBlockMap: [CFRunLoopActivity.RawValue: [ActivityBlock]] = [:]
    
    // Cycle tracking
    @dynamicMemberLookup
    private struct Cycle {
        var lastActivity: CFRunLoopActivity = .entry
        var counts: [CFRunLoopActivity.RawValue: UInt64] = [:]
        
        subscript(activity: CFRunLoopActivity) -> UInt64 {
            get {
                counts[activity.rawValue, default: 0]
            }
            set {
                counts[activity.rawValue] = newValue
            }
        }
        
        subscript(dynamicMember activity: String) -> UInt64 {
            get {
                counts[CFRunLoopActivity(activity).rawValue, default: 0]
            }
            set {
                counts[CFRunLoopActivity(activity).rawValue] = newValue
            }
        }
    }
    private var cycle: Cycle = Cycle()
}

extension RunLoopTracker {
    
    public func performOnNextCycle(_ block: @escaping () -> Void) {
        perform(in: 1, block)
    }
    
    public func perform(in cycles: UInt64, _ block: @escaping () -> Void) {
        
        lock.locked {
            print("[RLT:\(cycle.lastActivity.stringValue())] AC before perform: \(debugCycleString)")
            
            let act = ActivityBlock(block: {
                print("[RLT] AC after perform: \(self.debugCycleString)")
                block()
            }, cycle: cycle[cycle.lastActivity] + cycles )
            activityBlockMap[cycle.lastActivity.rawValue, default: []].append(act)
        }
    }
}

extension RunLoopTracker {
    public var debugCycleString: String {
        // not locking here on purposes
        "\(cycle.entry) \(cycle.beforeTimers) \(cycle.beforeSources) \(cycle.beforeWaiting) \(cycle.afterWaiting) \(cycle.exit)"
    }
}

// MARK: - Extensions -

internal extension CFRunLoopActivity {
    
    init(_ value: String) {
        
        let result: CFRunLoopActivity
        
        switch value {
        case "entry":
            result = CFRunLoopActivity.entry
            
        case "beforeTimers":
            result = CFRunLoopActivity.beforeTimers
            
        case "beforeSources":
            result = CFRunLoopActivity.beforeSources
            
        case "beforeWaiting":
            result = CFRunLoopActivity.beforeWaiting
            
        case "afterWaiting":
            result = CFRunLoopActivity.afterWaiting
            
        case "exit":
            result = CFRunLoopActivity.exit
            
        default:
            result = CFRunLoopActivity.allActivities
        }
        self.init(rawValue: result.rawValue)
    }
    
    func stringValue() -> String {
        switch self {
        case .entry:
            "entry"
            
        case .beforeTimers:
            "beforeTimers"
            
        case .beforeSources:
            "beforeSources"
            
        case .beforeWaiting:
            "beforeWaiting"
            
        case .afterWaiting:
            "afterWaiting"
            
        case .exit:
            "exit"
            
        default:
            "default"
        }
    }
}
