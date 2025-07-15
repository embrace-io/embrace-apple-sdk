//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
import EmbraceConfiguration
#endif

/// Remote config uses the Embrace Config Service to request config values
public class RemoteConfig {

    let logger: InternalLogger

    // config requests
    @ThreadSafe var payload: RemoteConfigPayload
    let fetcher: RemoteConfigFetcher

    // threshold values
    static let deviceIdUsedDigits: UInt = 6
    let deviceIdHexValue: UInt64

    @ThreadSafe private(set) var updating = false

    let cacheURL: URL?

    public convenience init(
        options: RemoteConfig.Options,
        payload: RemoteConfigPayload = RemoteConfigPayload(),
        logger: InternalLogger
    ) {
        self.init(options: options,
                  fetcher: RemoteConfigFetcher(options: options, logger: logger),
                  logger: logger)
    }

    init(
        options: RemoteConfig.Options,
        payload: RemoteConfigPayload = RemoteConfigPayload(),
        fetcher: RemoteConfigFetcher,
        logger: InternalLogger
    ) {
        self.payload = payload
        self.fetcher = fetcher
        self.deviceIdHexValue = options.deviceId.intValue(digitCount: Self.deviceIdUsedDigits)
        self.logger = logger

        if let url = options.cacheLocation {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            self.cacheURL = options.cacheLocation?.appendingPathComponent("cache")
            loadFromCache()
        } else {
            self.cacheURL = nil
        }
    }

    func loadFromCache() {
        guard let url = cacheURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            payload = try JSONDecoder().decode(RemoteConfigPayload.self, from: data)
        } catch {
            logger.error("Error loading cached remote config!")
        }
    }

    func saveToCache(_ data: Data?) {
        guard let url = cacheURL,
              let data = data else {
            return
        }

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            logger.warning("Error saving remote config cache!")
        }
    }
}

extension RemoteConfig: EmbraceConfigurable {
    public var isSDKEnabled: Bool { isEnabled(threshold: payload.sdkEnabledThreshold) }

    public var isBackgroundSessionEnabled: Bool { isEnabled(threshold: payload.backgroundSessionThreshold) }

    public var isNetworkSpansForwardingEnabled: Bool { isEnabled(threshold: payload.networkSpansForwardingThreshold) }

    public var isUiLoadInstrumentationEnabled: Bool { payload.uiLoadInstrumentationEnabled }

    public var isMetricKitEnabled: Bool { isEnabled(threshold: payload.metricKitEnabledThreshold) }

    public var isMetricKitCrashCaptureEnabled: Bool { payload.metricKitCrashCaptureEnabled }

    public var metricKitCrashSignals: [String] { payload.metricKitCrashSignals }

    public var isMetricKitHangCaptureEnabled: Bool { payload.metricKitHangCaptureEnabled }

    public var isSwiftUiViewInstrumentationEnabled: Bool { payload.swiftUiViewInstrumentationEnabled }

    public var networkPayloadCaptureRules: [NetworkPayloadCaptureRule] { payload.networkPayloadCaptureRules }

    public var spanEventsLimits: SpanEventsLimits {
        SpanEventsLimits(
            breadcrumb: UInt(max(payload.breadcrumbLimit, 0))
        )
    }

    public var logsLimits: LogsLimits {
        LogsLimits(
            info: UInt(max(payload.logsInfoLimit, 0)),
            warning: UInt(max(payload.logsWarningLimit, 0)),
            error: UInt(max(payload.logsErrorLimit, 0))
        )
    }

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
        fetcher.fetch { [weak self] newPayload, data in
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

            strongSelf.saveToCache(data)

            completion(didUpdate, nil)
        }
    }
}

extension RemoteConfig {
    func isEnabled(threshold: Float) -> Bool {
        return Self.isEnabled(hexValue: deviceIdHexValue, digits: Self.deviceIdUsedDigits, threshold: threshold)
    }

    /// Algorithm to determine if percentage threshold is enabled for the hexValue
    /// Given a `hexValue` (derived from DeviceIdentifier to persist across app launches)
    /// Determine the max value for the probability `space` by using the number of `digits` (16 ^ `n`)
    /// If the `hexValue` is within the `threshold`
    /// ```
    /// space = 16^numDigits - 1
    /// result = (hexValue / space) * 100.0 <= threshold
    /// ```
    /// - Parameters:
    ///  - hexValue: The value to test
    ///  - digits: The number of digits used to calculate the total space. Must match the number of digits used to determine the hexValue
    ///  - threshold: The percentage threshold to test against. Values between 0.0 and 100.0
    static func isEnabled(hexValue: UInt64, digits: UInt, threshold: Float) -> Bool {
        guard threshold > 0 else {
            return false
        }

        let space = powf(16, Float(digits)) - 1
        let result = (Float(hexValue) / space) * 100

        return result <= min(100, threshold)
    }
}
