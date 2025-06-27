//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
import EmbraceConfiguration
#endif

public extension Notification.Name {
    static let embraceConfigUpdated = Notification.Name("embraceConfigUpdated")
}

public class EmbraceConfig {

    public let options: Options
    let logger: InternalLogger
    let notificationCenter: NotificationCenter

    @ThreadSafe private var lastUpdateTime: TimeInterval = Date(timeIntervalSince1970: 0).timeIntervalSince1970

    public let configurable: EmbraceConfigurable

    let queue: DispatchableQueue

    public init(
        configurable: EmbraceConfigurable,
        options: Options,
        notificationCenter: NotificationCenter,
        logger: InternalLogger,
        queue: DispatchableQueue = .with(label: "com.embrace.config", attributes: .concurrent)
    ) {
        self.options = options
        self.notificationCenter = notificationCenter
        self.logger = logger
        self.configurable = configurable
        self.queue = queue

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
        return true
    }

    public func update() {
        self.queue.async { [weak self] in
            self?.configurable.update { [weak self] didChange, error in
                if let error = error {
                    self?.logger.error(
                        "Failed update in EmbraceConfig",
                        attributes: [ "error.message": error.localizedDescription ]
                    )
                }

                self?.lastUpdateTime = Date().timeIntervalSince1970

                if didChange {
                    self?.notificationCenter.post(name: .embraceConfigUpdated, object: self)
                }
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
        configurable.isSDKEnabled
    }

    public var isBackgroundSessionEnabled: Bool {
        configurable.isBackgroundSessionEnabled
    }

    public var isNetworkSpansForwardingEnabled: Bool {
        configurable.isNetworkSpansForwardingEnabled
    }

    public var isUiLoadInstrumentationEnabled: Bool {
        configurable.isUiLoadInstrumentationEnabled
    }

    public var isMetrickKitEnabled: Bool {
        configurable.isMetricKitEnabled
    }

    public var isMetricKitCrashCaptureEnabled: Bool {
        configurable.isMetricKitCrashCaptureEnabled
    }

    public var metricKitCrashSignals: [CrashSignal] {
        configurable.metricKitCrashSignals.compactMap {
            CrashSignal.from(string: $0)
        }
    }

    public var isMetricKitHangCaptureEnabled: Bool {
        configurable.isMetricKitHangCaptureEnabled
    }
    
    public var isSwiftUiViewInstrumentationEnabled: Bool {
        return configurable.isSwiftUiViewInstrumentationEnabled
    }
    
    public var internalLogLimits: InternalLogLimits {
         configurable.internalLogLimits
    }

    public var networkPayloadCaptureRules: [NetworkPayloadCaptureRule] {
        configurable.networkPayloadCaptureRules
    }
}
