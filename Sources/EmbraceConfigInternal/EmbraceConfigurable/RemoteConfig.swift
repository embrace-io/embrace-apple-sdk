//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal

/// Remote config uses the Embrace Config Service to request config values
public class RemoteConfig {

    // config requests
    @ThreadSafe private var payload: RemoteConfigPayload
    let fetcher: RemoteConfigFetcher

    // threshold values
    let deviceIdUsedDigits = 6
    var deviceIdHexValue: UInt64 = UInt64.max // defaults to everything disabled

    @ThreadSafe private(set) var updating = false

    public init(
        payload: RemoteConfigPayload = RemoteConfigPayload(),
        fetcher: RemoteConfigFetcher,
        deviceIdHexValue: UInt64,
        updating: Bool = false
    ) {
        self.payload = payload
        self.fetcher = fetcher
        self.deviceIdHexValue = deviceIdHexValue
        self.updating = updating
    }

    public func update() {
        guard updating == false else {
            return
        }

        updating = true
        fetcher.fetch { [self] newPayload in
            defer { updating = false }
            guard let newPayload = newPayload else {
                return
            }

            payload = newPayload
        }
    }
}

extension RemoteConfig: EmbraceConfigurable {
    public var isSDKEnabled: Bool { isEnabled(threshold: payload.sdkEnabledThreshold) }

    public var isBackgroundSessionEnabled: Bool { isEnabled(threshold: payload.backgroundSessionThreshold) }

    public var isNetworkSpansForwardingEnabled: Bool { isEnabled(threshold: payload.networkSpansForwardingThreshold) }

    public var internalLogLimits: InternalLogLimits {
        InternalLogLimits(
            trace: UInt(max(payload.internalLogsTraceLimit, 0)),
            debug: UInt(max(payload.internalLogsDebugLimit, 0)),
            info: UInt(max(payload.internalLogsInfoLimit, 0)),
            warning: UInt(max(payload.internalLogsWarningLimit, 0)),
            error: UInt(max(payload.internalLogsErrorLimit, 0))
        )
    }
}

extension RemoteConfig {
    func isEnabled(threshold: Float) -> Bool {
        return Self.isEnabled(hexValue: deviceIdHexValue, digits: deviceIdUsedDigits, threshold: threshold)
    }

    static func isEnabled(hexValue: UInt64, digits: Int, threshold: Float) -> Bool {
        let space = powf(16, Float(digits))
        let result = (Float(hexValue) / space) * 100

        return result < threshold
    }
}
