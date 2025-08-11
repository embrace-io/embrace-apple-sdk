//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

#if canImport(UIKit) && !os(watchOS)
    import UIKit

    /// This class is a wrapper around `UIApplication.shared.beginBackgroundTask`.
    /// Based off https://developer.apple.com/forums/thread/85066 and https://developer.apple.com/forums/thread/729335

    class BackgroundTaskAssertion {

        let name: String
        private var taskID: UIBackgroundTaskIdentifier = .invalid
        private static let taskProvider: BackgroundTaskProvider = BackgroundTaskProvider()

        init?(name: String, logger: InternalLogger) {

            self.name = name

            let taskID = Self.taskProvider.beginBackgroundTask(withName: name) { [weak self] in
                logger.critical("Background task \(name) expired!")
                self?.endTask()
            }
            self.taskID = taskID

            if taskID == .timeout {
                logger.critical("Cannot create background task \(name), out of background time!")
                return nil
            }

            if taskID == .invalid {
                logger.critical("Failed to create background task \(name), no valid ID!")
                return nil
            }
        }

        deinit {
            endTask()
        }

        func finish() {
            endTask()
        }

        private func endTask() {
            if taskID == .invalid || taskID == .noApp || taskID == .timeout {
                return
            }

            Self.taskProvider.endBackgroundTask(self.taskID)
            logger.debug("[BG:END:\(taskID.rawValue)] \(name)")

            taskID = .invalid
        }
    }

    extension UIBackgroundTaskIdentifier {
        public static let timeout: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier(rawValue: Int.max - 1)
        public static let noApp: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier(rawValue: Int.max - 2)
    }

    private class BackgroundTaskProvider {

        // App can be nil on some occasions such as before
        // the UIApplication has actually been created.
        // For this, we have our own optional UIApplication getter.
        private var app: UIApplication? {
            UIApplication.shared as UIApplication?
        }

        func beginBackgroundTask(withName taskName: String, expirationHandler handler: @escaping () -> Void)
            -> UIBackgroundTaskIdentifier
        {
            // If app is nil, we have a special identifier.
            // For now, this allows our code to continue working,
            // and run things even when UIApplication isn't ready yet.
            guard let app else {
                return .noApp
            }

            guard canStartTask(app) else {
                return .timeout
            }

            let id: UIBackgroundTaskIdentifier = app.beginBackgroundTask(
                withName: "\(taskName)",
                expirationHandler: handler
            )
            logger.debug("[BG:START:\(id.rawValue)] \(taskName)")
            return id
        }

        func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier) {
            app?.endBackgroundTask(identifier)
        }

        // Timing
        private var knownTimeRemain: TimeInterval = 0
        private var lastTimeRemainCheck: CFAbsoluteTime = 0
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

    typealias UIBackgroundTaskIdentifier = UInt

    // TODO: Implement WatchOS Version
    class BackgroundTaskAssertion {

        let name: String
        private var taskID: UIBackgroundTaskIdentifier

        init?(name: String, logger: InternalLogger) {
            self.name = name
            self.taskID = 0
        }

        deinit {
            endTask()
        }

        func finish() {
            endTask()
        }

        private func endTask() {
        }
    }

#endif
