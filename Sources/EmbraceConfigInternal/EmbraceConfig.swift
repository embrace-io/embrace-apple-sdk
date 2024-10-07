//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceConfiguration

public extension Notification.Name {
    static let embraceConfigUpdated = Notification.Name("embraceConfigUpdated")
}

public class EmbraceConfig {

    public let options: Options
    let logger: InternalLogger
    let notificationCenter: NotificationCenter

    @ThreadSafe private var lastUpdateTime: TimeInterval = Date(timeIntervalSince1970: 0).timeIntervalSince1970

    let configurable: EmbraceConfigurable

    public init(
        configurable: EmbraceConfigurable,
        options: Options,
        notificationCenter: NotificationCenter,
        logger: InternalLogger
    ) {
        self.options = options
        self.notificationCenter = notificationCenter
        self.logger = logger
        self.configurable = configurable

        update()

        // using hardcoded string to avoid reference to UIApplication reference
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSNotification.Name("UIApplicationDidBecomeActiveNotification"),
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Update
    @discardableResult
    public func updateIfNeeded() -> Bool {
        guard Date().timeIntervalSince1970 - lastUpdateTime > options.minimumUpdateInterval else {
            return false
        }

        update()
        lastUpdateTime = Date().timeIntervalSince1970
        return true
    }

    public func update() {
        configurable.update { [weak self] didChange, error in
            if let error = error {
                self?.logger.error(
                    "Failed update in EmbraceConfig",
                    attributes: [ "error.message": error.localizedDescription ]
                )
            }

            if didChange {
                self?.notificationCenter.post(name: .embraceConfigUpdated, object: self)
            }
        }
    }

    // MARK: - Notifications
    @objc func appDidBecomeActive() {
        self.updateIfNeeded()
    }
}

extension EmbraceConfig /* EmbraceConfigurable delegation */ {
    public var isSDKEnabled: Bool {
        return configurable.isSDKEnabled
    }

    public var isBackgroundSessionEnabled: Bool {
        return configurable.isBackgroundSessionEnabled
    }

    public var isNetworkSpansForwardingEnabled: Bool {
        return configurable.isNetworkSpansForwardingEnabled
    }

    public var internalLogLimits: InternalLogLimits {
        return configurable.internalLogLimits
    }

    public var networkPayloadCaptureRules: [NetworkPayloadCaptureRule] {
        return configurable.networkPayloadCaptureRules
    }
}
