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
    let _payload: EmbraceMutex<RemoteConfigPayload>
    var payload: RemoteConfigPayload {
        get { _payload.withLock { $0 } }
        set { _payload.withLock { $0 = newValue } }
    }
    let fetcher: RemoteConfigFetcher

    // threshold values
    static let deviceIdUsedDigits: UInt = 6
    let deviceIdHexValue: UInt64

    private let updating = EmbraceAtomic<Bool>(false)

    let cacheURL: URL?

    public convenience init(
        options: RemoteConfig.Options,
        payload: RemoteConfigPayload = RemoteConfigPayload(),
        logger: InternalLogger
    ) {
        self.init(
            options: options,
            fetcher: RemoteConfigFetcher(options: options, logger: logger),
            logger: logger)
    }

    init(
        options: RemoteConfig.Options,
        payload: RemoteConfigPayload = RemoteConfigPayload(),
        fetcher: RemoteConfigFetcher,
        logger: InternalLogger
    ) {
        self._payload = EmbraceMutex(payload)
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
            FileManager.default.fileExists(atPath: url.path)
        else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(RemoteConfigPayload.self, from: data)
            _payload.withLock { $0 = decoded }
            logHangLimitCorrections(for: decoded)
        } catch {
            logger.error("Error loading cached remote config!")
        }
    }

    func saveToCache(_ data: Data?) {
        guard let url = cacheURL,
            let data = data
        else {
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
    public var hangLimits: HangLimits {
        HangLimits(
            hangThreshold: payload.hangLimitsHangThreshold,
            hangPerSession: payload.hangLimitsHangPerSession,
            reportsWatchdogEvents: payload.hangLimitsReportsWatchdogEvents,
            sampleTriggerThreshold: payload.hangLimitsSampleTriggerThreshold,
            samplePollInterval: payload.hangLimitsSamplePollInterval
        )
    }

    public var experimentsLimits: ExperimentsLimits {
        ExperimentsLimits(
            maxCount: payload.maxExperimentCount,
            maxIdLength: payload.maxExperimentIdLength,
            maxVariantLength: payload.maxExperimentVariantLength
        )
    }

    public var isSDKEnabled: Bool { isEnabled(threshold: payload.sdkEnabledThreshold) }

    public var isBackgroundSessionEnabled: Bool { isEnabled(threshold: payload.backgroundSessionThreshold) }

    public var isNetworkSpansForwardingEnabled: Bool { isEnabled(threshold: payload.nsfThreshold ?? 0) }

    public var traceparentInjectionEnabled: Bool { isEnabled(threshold: payload.traceparentInjectionThreshold ?? 0) }

    public var isUiLoadInstrumentationEnabled: Bool { payload.uiLoadInstrumentationEnabled }

    public var isWalModeEnabled: Bool { isEnabled(threshold: payload.walModeThreshold) }

    public var viewControllerClassNameBlocklist: [String] { payload.viewControllerClassNameBlocklist }

    public var uiInstrumentationCaptureHostingControllers: Bool { payload.uiInstrumentationCaptureHostingControllers }

    public var isSwiftUiViewInstrumentationEnabled: Bool { payload.swiftUiViewInstrumentationEnabled }

    public var isMetricKitEnabled: Bool { isEnabled(threshold: payload.metricKitEnabledThreshold) }

    public var isMetricKitCrashCaptureEnabled: Bool { payload.metricKitCrashCaptureEnabled }

    public var metricKitCrashSignals: [String] { payload.metricKitCrashSignals }

    public var isMetricKitHangCaptureEnabled: Bool { payload.metricKitHangCaptureEnabled }

    public var isMetricKitInternalMetricsCaptureEnabled: Bool { payload.metricKitInternalMetricsCaptureEnabled }

    public var networkPayloadCaptureRules: [NetworkPayloadCaptureRule] { payload.networkPayloadCaptureRules }

    public var spanEventTypeLimits: SpanEventTypeLimits {
        SpanEventTypeLimits(
            breadcrumb: UInt(max(payload.breadcrumbLimit, 0)),
            tap: UInt(max(payload.tapLimit, 0))
        )
    }

    public var logSeverityLimits: LogSeverityLimits {
        LogSeverityLimits(
            info: UInt(max(payload.logsInfoLimit, 0)),
            warn: UInt(max(payload.logsWarningLimit, 0)),
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

    public var useNewStorageForSpanEvents: Bool { payload.useNewStorageForSpanEvents }

    public var userSessionMaxDuration: TimeInterval { payload.userSessionMaxDurationSeconds }

    public var userSessionInactivityTimeout: TimeInterval { payload.userSessionInactivityTimeoutSeconds }

    public func update(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard updating == false else {
            completion(.success(false))
            return
        }

        self.updating.store(true)
        fetcher.fetch { [weak self] newPayload, data in
            defer { self?.updating.store(false) }
            guard let strongSelf = self else {
                completion(.success(false))
                return
            }

            guard let newPayload = newPayload else {
                completion(.success(false))
                return
            }

            let didUpdate = strongSelf._payload.withLock {
                let changed = $0 != newPayload
                $0 = newPayload
                return changed
            }
            if didUpdate {
                strongSelf.logHangLimitCorrections(for: newPayload)
            }
            strongSelf.saveToCache(data)

            completion(.success(didUpdate))
        }
    }
}

extension RemoteConfig {

    /// Descriptions of any hang-limit payload values that were *invalid* and had to be corrected — a
    /// non-finite/non-positive fallback, an out-of-range clamp, or a `sampleTriggerThreshold` at or
    /// above `hangThreshold`. Empty when the payload is valid. The routine cap that keeps the trigger
    /// a margin below `hangThreshold` is expected policy, not a misconfiguration, so a valid in-range
    /// request the cap merely trims is deliberately *not* reported. `HangLimits` applies all of this
    /// silently (by design — it can't reach a logger and must not trap), so this surfaces the genuine
    /// misconfigurations one layer up where a bad remote-config push can be diagnosed. Pure, so it can
    /// be unit-tested without the fetch/logging plumbing.
    static func hangLimitCorrections(for payload: RemoteConfigPayload) -> [String] {
        let limits = HangLimits(
            hangThreshold: payload.hangLimitsHangThreshold,
            hangPerSession: payload.hangLimitsHangPerSession,
            reportsWatchdogEvents: payload.hangLimitsReportsWatchdogEvents,
            sampleTriggerThreshold: payload.hangLimitsSampleTriggerThreshold,
            samplePollInterval: payload.hangLimitsSamplePollInterval
        )

        var corrections: [String] = []

        if limits.hangThreshold != payload.hangLimitsHangThreshold {
            corrections.append(
                "hang_threshold \(payload.hangLimitsHangThreshold) → \(limits.hangThreshold) "
                    + "(not finite or <= 0; reset to default)")
        }

        // The trigger is routinely capped at a fraction of hang_threshold; that's expected policy, not
        // a misconfiguration — so a valid request (`[floor, hang_threshold)`) is never reported even
        // when the cap trims it. Only genuinely invalid values warn.
        let rawTrigger = payload.hangLimitsSampleTriggerThreshold
        let triggerReason: String?
        if !rawTrigger.isFinite {
            triggerReason = "not finite; reset to default"
        } else if rawTrigger < HangLimits.minSampleTriggerThreshold {
            triggerReason = "below the floor of \(HangLimits.minSampleTriggerThreshold); clamped up"
        } else if rawTrigger > HangLimits.maxSampleTriggerThreshold {
            triggerReason = "above the max of \(HangLimits.maxSampleTriggerThreshold) (a seconds/ms mixup?); capped"
        } else if rawTrigger >= limits.hangThreshold {
            triggerReason = "at or above hang_threshold (\(limits.hangThreshold)); capped"
        } else {
            triggerReason = nil
        }
        if let triggerReason {
            corrections.append("sample_trigger_threshold \(rawTrigger) → \(limits.sampleTriggerThreshold) (\(triggerReason))")
        }

        if limits.samplePollInterval != payload.hangLimitsSamplePollInterval {
            let raw = payload.hangLimitsSamplePollInterval
            let reason =
                raw.isFinite
                ? "out of [\(HangLimits.minSamplePollInterval), \(HangLimits.maxSamplePollInterval)]; clamped"
                : "not finite; reset to default"
            corrections.append("sample_poll_interval \(raw) → \(limits.samplePollInterval) (\(reason))")
        }

        return corrections
    }

    /// Logs a warning for each hang-limit value the incoming payload had to have corrected.
    func logHangLimitCorrections(for payload: RemoteConfigPayload) {
        for correction in Self.hangLimitCorrections(for: payload) {
            logger.warning("[Hang] remote config value out of range, corrected: \(correction)")
        }
    }

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
