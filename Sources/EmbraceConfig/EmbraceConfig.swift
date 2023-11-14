//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

public class EmbraceConfig {

    public let options: Options

    let deviceIdUsedDigits = 6
    var deviceIdHexValue: UInt64 = UInt64.max // defaults to everything disabled

    @ThreadSafe var payload: RemoteConfigPayload = RemoteConfigPayload()
    let fetcher: RemoteConfigFetcher

    @ThreadSafe private var updating = false
    @ThreadSafe private var lastUpdateTime: TimeInterval = Date(timeIntervalSince1970: 0).timeIntervalSince1970

    public init(options: Options) {
        self.options = options
        fetcher = RemoteConfigFetcher(options: options)
        update()

        // get hex value of the last 6 digits of the device id
        if options.deviceId.count >= deviceIdUsedDigits {
            let hexString = String(options.deviceId.suffix(deviceIdUsedDigits))
            let scanner = Scanner(string: hexString)
            scanner.scanHexInt64(&deviceIdHexValue)
        }
    }

    // MARK: - Configs
    public var isSDKEnabled: Bool {
        return isEnabled(threshold: payload.sdkEnabledThreshold)
    }

    public var isBackgroundSessionEnabled: Bool {
        return isEnabled(threshold: payload.backgroundSessionThreshold)
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
                self?.payload = payload
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
}
