//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//
import CoreData
import Foundation

#if canImport(UIKit)
    import UIKit
#endif
#if os(watchOS)
    import WatchKit
#endif
#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

// The work tracker is meant to track core data work through a ref count.
// Each decrement allows a leeway of N seconds in order to group spurts of
// work. This allows us to ensure that, when required, we can do other work once
// that group of work is done, such as run a background task assertion
// to finish up work on backgrounding.

typealias WorkTrackerID = UInt64

internal class WorkTracker {

    let name: String
    let logger: InternalLogger
    var observer: NSObjectProtocol?
    let queue: DispatchQueue

    struct BusyData {
        var liveIDs: Set<WorkTrackerID> = Set()
        var currentID: WorkTrackerID = 1
        var onIdle: (() -> Void)?
    }
    private var _busyData = EmbraceMutex(BusyData())

    init(name: String, logger: InternalLogger) {
        self.name = name
        self.logger = logger
        self.observer = nil
        self.queue = DispatchQueue(label: "WorkTracker.\(name)", qos: .utility, autoreleaseFrequency: .workItem)

        #if canImport(UIKit) && !os(watchOS)
            self.observer = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil
            ) { [weak self] _ in
                self?.didEnterBackground()
            }
        #elseif os(watchOS)
            if #available(watchOS 7.0, *) {
                self.observer = NotificationCenter.default.addObserver(
                    forName: WKExtension.applicationDidEnterBackgroundNotification, object: nil, queue: nil
                ) { [weak self] _ in
                    self?.didEnterBackground()
                }
            }
        #endif
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public func increment(_ label: String = #function) -> WorkTrackerID {
        return _busyData.withLock {
            let nextId = $0.currentID
            $0.liveIDs.insert(nextId)
            $0.currentID += 1
            return nextId
        }
    }

    public func decrement(
        _ label: String = #function, id: WorkTrackerID, afterDebounce: Bool, debounceInterval: TimeInterval = 2.0
    ) {
        if afterDebounce {
            queue.asyncAfter(deadline: .now() + debounceInterval) { [self] in
                _decrement(label, id: id)
            }
        } else {
            _decrement(label, id: id)
        }
    }

    private func _decrement(_ label: String = #function, id: WorkTrackerID) {
        let value: (() -> Void)? = _busyData.withLock {

            // check and remove form the live set
            guard $0.liveIDs.remove(id) != nil else {
                logger.critical("[BG] \(name) trying to decrement id \(id) that isn't live")
                return nil
            }

            guard $0.liveIDs.isEmpty else {
                return nil
            }

            let block = $0.onIdle
            $0.onIdle = nil
            return block
        }
        if let value {
            value()
        }
    }

    public var busy: Bool {
        _busyData.withLock { $0.liveIDs.isEmpty == false }
    }

    public func onIdle(_ block: (() -> Void)?) {
        let value = _busyData.withLock {
            if $0.liveIDs.isEmpty {
                $0.onIdle = nil
                return block
            }
            $0.onIdle = block
            return nil
        }
        if let value {
            value()
        }
    }

    /// Called when the app is backgrounded on certain platforms that require extra time
    /// for the database to finish up its work.
    private func didEnterBackground() {

        // In essence, we want a task assertion to run on backgrounding to make
        // sure all our core data work has time to finish.
        let task = BackgroundTaskAssertion(name: "embrace.coredata.background.\(name)", logger: logger)
        let id = increment()
        onIdle {
            task?.finish()
        }
        decrement(id: id, afterDebounce: true)
    }
}
