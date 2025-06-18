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
class BackgroundTaskWrapper {

    let name: String
    private var taskID: UIBackgroundTaskIdentifier

    init?(name: String, logger: InternalLogger) {
        // This should never be called from the main thread
        // since we are checking for `UIApplication.shared.backgroundTimeRemaining`.
        //
        // Note: In the current context of things, this class is only used internally
        // within this module, and it's always called from the core data wrapper context thread
        // which should never be the main thread.
        // Leaving the check anyways just in case.
        if Thread.isMainThread {
            return nil
        }

        // do not create task if there's not enough time until suspension
        if UIApplication.shared.backgroundTimeRemaining <= 5 {
            return nil
        }

        self.name = name
        self.taskID = .invalid

        let taskID = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            logger.critical("Background task \(name) cancelled!")
            self?.endTask()
        }

        // handle case where the task can't be created
        if taskID == .invalid {
            return nil
        }
        self.taskID = taskID
    }

    deinit {
        self.endTask()
    }

    func finish() {
        self.endTask()
    }

    private func endTask() {
        guard self.taskID != .invalid else {
            return
        }

        UIApplication.shared.endBackgroundTask(self.taskID)
        self.taskID = .invalid
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
