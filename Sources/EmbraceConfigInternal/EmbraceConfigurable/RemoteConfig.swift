//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceConfiguration

/// Remote config uses the Embrace Config Service to request config values
public class RemoteConfig {

    // config requests
    @ThreadSafe var payload: RemoteConfigPayload
    let fetcher: RemoteConfigFetcher

    // threshold values
    let deviceIdUsedDigits: UInt
    let deviceIdHexValue: UInt64

    @ThreadSafe private(set) var updating = false

    public init(
        payload: RemoteConfigPayload = RemoteConfigPayload(),
        fetcher: RemoteConfigFetcher,
        deviceIdHexValue: UInt64 = UInt64.max /* default to everything disabled */,
        deviceIdUsedDigits: UInt
    ) {
        self.payload = payload
        self.fetcher = fetcher
        self.deviceIdHexValue = deviceIdHexValue
        self.deviceIdUsedDigits = deviceIdUsedDigits
    }
}

extension RemoteConfig: EmbraceConfigurable {
    public var isSDKEnabled: Bool { isEnabled(threshold: payload.sdkEnabledThreshold) }

    public var isBackgroundSessionEnabled: Bool { isEnabled(threshold: payload.backgroundSessionThreshold) }

    public var isNetworkSpansForwardingEnabled: Bool { isEnabled(threshold: payload.networkSpansForwardingThreshold) }

    public var networkPayloadCaptureRules: [NetworkPayloadCaptureRule] { payload.networkPayloadCaptureRules }

    public var internalLogLimits: InternalLogLimits {
        InternalLogLimits(
            trace: UInt(max(payload.internalLogsTraceLimit, 0)),
            debug: UInt(max(payload.internalLogsDebugLimit, 0)),
            info: UInt(max(payload.internalLogsInfoLimit, 0)),
            warning: UInt(max(payload.internalLogsWarningLimit, 0)),
            error: UInt(max(payload.internalLogsErrorLimit, 0))
        )
    }

    public func update(completion: @escaping (Bool, (any Error)?) -> Void) {
        guard updating == false else {
            completion(false, nil)
            return
        }

        updating = true
        fetcher.fetch { [weak self] newPayload in
            defer { self?.updating = false }
            guard let strongSelf = self else {
                completion(false, nil)
                return
            }

            guard let newPayload = newPayload else {
                completion(false, nil)
                return
            }

            let didUpdate = strongSelf.payload != newPayload
            strongSelf.payload = newPayload

            completion(didUpdate, nil)
        }
    }
}

extension RemoteConfig {
    func isEnabled(threshold: Float) -> Bool {
        return Self.isEnabled(hexValue: deviceIdHexValue, digits: deviceIdUsedDigits, threshold: threshold)
    }

    /// Algorithm to determine if percentage threshold is enabled for the hexValue
    /// Given a `hexValue` (derived from DeviceIdentifier to persist across app launches)
    /// Determine the max value for the probability `space` by using the number of `digits` (16 ^ `n`)
    /// If the `hexValue` is within the `threshold`
    /// ```
    /// space = 16^numDigits
    /// result = (hexValue / space) * 100.0 < threshold
    /// ```
    /// - Parameters:
    ///  - hexValue: The value to test
    ///  - digits: The number of digits used to calculate the total space. Must match the number of digits used to determine the hexValue
    ///  - threshold: The percentage threshold to test against. Values between 0.0 and 100.0
    static func isEnabled(hexValue: UInt64, digits: UInt, threshold: Float) -> Bool {
        let space = powf(16, Float(digits))
        let result = (Float(hexValue) / space) * 100

        return result < threshold
    }
}
