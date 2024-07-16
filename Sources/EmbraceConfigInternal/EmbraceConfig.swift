//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal

public extension Notification.Name {
    static let embraceConfigUpdated = Notification.Name("embraceConfigUpdated")
}

public class EmbraceConfig {

    public let options: Options
    let logger: InternalLogger
    let notificationCenter: NotificationCenter

    let deviceIdUsedDigits = 6
    var deviceIdHexValue: UInt64 = UInt64.max // defaults to everything disabled

    @ThreadSafe var payload: RemoteConfigPayload = RemoteConfigPayload()
    let fetcher: RemoteConfigFetcher

    @ThreadSafe private(set) var updating = false
    @ThreadSafe private var lastUpdateTime: TimeInterval = Date(timeIntervalSince1970: 0).timeIntervalSince1970

    public var onUpdate: (() -> Void)?

    public init(options: Options, notificationCenter: NotificationCenter, logger: InternalLogger) {
        self.options = options
        self.notificationCenter = notificationCenter
        self.logger = logger

        fetcher = RemoteConfigFetcher(options: options, logger: logger)
        update()

        // get hex value of the last 6 digits of the device id
        if options.deviceId.count >= deviceIdUsedDigits {
            let hexString = String(options.deviceId.suffix(deviceIdUsedDigits))
            let scanner = Scanner(string: hexString)
            scanner.scanHexInt64(&deviceIdHexValue)
        }

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

    // MARK: - Configs
    public var isSDKEnabled: Bool {
        return isEnabled(threshold: payload.sdkEnabledThreshold)
    }

    public var isBackgroundSessionEnabled: Bool {
        return isEnabled(threshold: payload.backgroundSessionThreshold)
    }

    public var isNetworkSpansForwardingEnabled: Bool {
        return isEnabled(threshold: payload.networkSpansForwardingThreshold)
    }

    public var internalLogsTraceLimit: Int {
        return payload.internalLogsTraceLimit
    }

    public var internalLogsDebugLimit: Int {
        return payload.internalLogsDebugLimit
    }

    public var internalLogsInfoLimit: Int {
        return payload.internalLogsInfoLimit
    }

    public var internalLogsWarningLimit: Int {
        return payload.internalLogsWarningLimit
    }

    public var internalLogsErrorLimit: Int {
        return payload.internalLogsErrorLimit
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
        guard updating == false else {
            return
        }

        updating = true

        fetcher.fetch { [weak self] payload in
            if let payload = payload {
                let previousPayload = self?.payload

                self?.payload = payload

                if previousPayload != payload {
                    self?.notificationCenter.post(name: .embraceConfigUpdated, object: nil)
                }

                self?.lastUpdateTime = Date().timeIntervalSince1970
            }

            self?.updating = false
        }
    }

    // MARK: - Private
    func isEnabled(threshold: Float) -> Bool {
        return EmbraceConfig.isEnabled(hexValue: deviceIdHexValue, digits: deviceIdUsedDigits, threshold: threshold)
    }

    class func isEnabled(hexValue: UInt64, digits: Int, threshold: Float) -> Bool {
        let space = powf(16, Float(digits))
        let result = (Float(hexValue) / space) * 100

        return result < threshold
    }

    // MARK: - Notifications
    @objc func appDidBecomeActive() {
        self.updateIfNeeded()
    }
}
