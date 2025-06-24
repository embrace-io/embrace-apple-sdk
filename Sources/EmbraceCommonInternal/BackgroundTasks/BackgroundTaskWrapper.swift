//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if canImport(UIKit) && !os(watchOS)
import UIKit
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
#endif

/// This class is a wrapper around `UIApplication.shared.beginBackgroundTask`.
/// Based off https://developer.apple.com/forums/thread/85066 and https://developer.apple.com/forums/thread/729335

public class BackgroundTaskWrapper {
    
    public let name: String
    private var taskID: UIBackgroundTaskIdentifier = .invalid
    private static let taskProvider: BackgroundTaskProvider = BackgroundTaskProvider()
    
    public init?(name: String, expirationBlock: (() -> Void)? = nil) {

        self.name = name
        
        let taskID = Self.taskProvider.beginBackgroundTask(withName: name) { [weak self] in
            print("Background task \(name) expired!")
            expirationBlock?()
            self?.endTask()
        }
        self.taskID = taskID

        if taskID == .timeout {
            print("Cannot create background task \(name), out of background time!")
            return nil
        }
        
        // handle case where the task can't be created
        if taskID == .invalid {
            print("Failed to create background task \(name), no valid ID!")
            return nil
        }
    }
    
    deinit {
        self.endTask()
    }
    
    public func finish() {
        self.endTask()
    }
    
    private func endTask() {
        guard taskID.rawValue > 0 else {
            return
        }
        Self.taskProvider.endBackgroundTask(self.taskID)
        self.taskID = .invalid
    }
}

extension UIBackgroundTaskIdentifier {
    
    public static let timeout: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier(rawValue: Int.max-1)
    
    public static let noApp: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier(rawValue: Int.max-2)
    
    var stringValue: String {
        if self == .invalid { return "bgtask: invalid" }
        if self == .timeout { return "bgtask: timeout" }
        if self == .noApp { return "bgtask: noApp" }
        return "bgtask: \(self.rawValue)"
    }
}

fileprivate class BackgroundTaskProvider {
    
    // App can be nil on some occasions such as before
    // the UIApplication has actually been created.
    // For this, we have our own optional UIApplication getter.
    private var app: UIApplication? {
        UIApplication.shared as UIApplication?
    }
    
    func beginBackgroundTask(withName taskName: String?, expirationHandler handler: @escaping () -> Void) -> UIBackgroundTaskIdentifier
    {
        // If app is nil, we have a special identifier.
        // For now, this allows our code to continue working,
        // and run things even when UIApplication isn't ready yet.
        guard let app else {
            print("[BackgroundTaskProvider] cannot start task, app isn't ready")
            return .noApp
        }
        
        guard canStartTask(app) else {
            print("[BackgroundTaskProvider] cannot start task, it would timeout")
            return .timeout
        }
        
        return lock.locked {
            if let curTask = currentTaskID {
                currentTaskRefCount += 1
                return curTask
            }
            
            var newTask: UIBackgroundTaskIdentifier? = nil
            newTask = app.beginBackgroundTask(withName: taskName) { [self] in
                lock.locked {
                    
                    print("[BackgroundTaskProvider] task expired \(newTask!.stringValue)")
                    
                    assert(newTask == currentTaskID)
                    
                    // Stop everything as quickly as possible
                    // This resets the whole system
                    latestTaskWorkItem?.cancel()
                    latestTaskWorkItem = nil
                    
                    if let t = currentTaskID {
                        app.endBackgroundTask(t)
                        currentTaskID = nil
                        currentTaskRefCount = 0
                    }
                }
                handler()
            }
            if newTask != .invalid {
                currentTaskID = newTask
                currentTaskRefCount = 1
                print("[BackgroundTaskProvider] begin \(newTask!.stringValue)")
            }
            return newTask ?? .invalid
        }
    }
    
    func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier) {
        lock.lock()
        defer { lock.unlock() }
        
        if identifier == .noApp || identifier == .timeout {
            return
        }
        
        guard identifier == currentTaskID else {
            print("[BackgroundTaskProvider] cannot end incorrect task \(identifier.stringValue) != \(currentTaskID?.stringValue)")
            return
        }
        
        currentTaskRefCount -= 1
        guard currentTaskRefCount == 0 else {
            return
        }
        
        // debounce
        latestTaskWorkItem?.cancel()
        latestTaskWorkItem = nil
        var workItem: DispatchWorkItem? = nil
        workItem = DispatchWorkItem { [self] in
            guard let workItem else {
                return
            }
            
            if workItem.isCancelled {
                print("[BackgroundTaskProvider] work item is cancelled")
                return
            }
            
            lock.lock()
            defer { lock.unlock() }
            
            guard identifier == currentTaskID else {
                print("[BackgroundTaskProvider] cannot end incorrect task after run loop \(identifier.stringValue) != \(currentTaskID?.stringValue)")
                return
            }
            
            guard currentTaskRefCount == 0 else {
                print("[BackgroundTaskProvider] won't end, ref count is \(currentTaskRefCount) after run loop tick")
                return
            }
            
            print("[BackgroundTaskProvider] end \(identifier.stringValue)")
            
            app?.endBackgroundTask(identifier)
            currentTaskID = nil
        }
        latestTaskWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: latestTaskWorkItem!)
    }

    // Timing
    private var knownTimeRemain: TimeInterval = 0
    private var lastTimeRemainCheck: CFAbsoluteTime = 0
    private var latestTaskWorkItem: DispatchWorkItem? = nil
    private var currentTaskID: UIBackgroundTaskIdentifier? = nil
    private var currentTaskRefCount: Int = 0
    private let lock: UnfairLock = UnfairLock()
    
    private func canStartTask(_ app: UIApplication) -> Bool {
        
        let now = CFAbsoluteTimeGetCurrent()
        
        // backgroundTimeRemaining is expensive to call
        // and we'll need to call it on the main queue sometimes,
        // so we cache it's value knowing we only need about 5 second precision.
        let timeRemain = lock.locked {
            if knownTimeRemain <= 0 || now - lastTimeRemainCheck >= 4 {
                lastTimeRemainCheck = now
                knownTimeRemain = app.backgroundTimeRemaining
            }
            return knownTimeRemain
        }
        
        // usually unlimited time due to being in the foreground
        if timeRemain >= Double.greatestFiniteMagnitude {
            return true
        }
        
        // less than 5 seconds left. We can't create a task since
        // the OS will not call our expiration.
        if timeRemain <= 5 {
            return false
        }
        
        return true
    }
}

#else

// TODO: Implement WatchOS Version
class BackgroundTaskWrapper {
    
    let name: String
    private var taskID: UIBackgroundTaskIdentifier
    
    init(name: String) {
        self.name = name
        self.taskID = .invalid
    }
    
    deinit {
        self.endTask()
    }
    
    func finish() {
        self.endTask()
    }
    
    private func endTask() {
        
    }
}

#endif
