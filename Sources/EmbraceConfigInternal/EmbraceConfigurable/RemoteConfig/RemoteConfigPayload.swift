//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceConfiguration
    import EmbraceCommonInternal
#endif

public struct RemoteConfigPayload: Decodable, Equatable {
    var sdkEnabledThreshold: Float
    var backgroundSessionThreshold: Float
    var networkSpansForwardingThreshold: Float
    var walModeThreshold: Float

    var uiLoadInstrumentationEnabled: Bool
    var viewControllerClassNameBlocklist: [String]
    var uiInstrumentationCaptureHostingControllers: Bool
    var swiftUiViewInstrumentationEnabled: Bool

    var metricKitEnabledThreshold: Float
    var metricKitCrashCaptureEnabled: Bool
    var metricKitCrashSignals: [String]
    var metricKitHangCaptureEnabled: Bool
    var metricKitInternalMetricsCaptureEnabled: Bool

    var breadcrumbLimit: Int
    var tapLimit: Int

    var logsInfoLimit: Int
    var logsWarningLimit: Int
    var logsErrorLimit: Int

    var internalLogsTraceLimit: Int
    var internalLogsDebugLimit: Int
    var internalLogsInfoLimit: Int
    var internalLogsWarningLimit: Int
    var internalLogsErrorLimit: Int

    var hangLimitsHangPerSession: UInt
    var hangLimitsSamplesPerHang: UInt
    var hangLimitsReportsWatchdogEvents: Bool

    var networkPayloadCaptureRules: [NetworkPayloadCaptureRule]

    var useLegacyUrlSessionProxy: Bool

    var useNewStorageForSpanEvents: Bool

    var userSessionMaxDurationSeconds: TimeInterval
    var userSessionInactivityTimeoutSeconds: TimeInterval

    enum CodingKeys: String, CodingKey {
        case sdkEnabledThreshold = "threshold"

        case background
        enum BackgroundCodingKeys: String, CodingKey {
            case threshold
        }

        case networkSpansForwarding = "network_span_forwarding"
        enum NetworkSpansForwardingCodingKeys: String, CodingKey {
            case threshold = "pct_enabled"
        }

        case walModeThreshold = "core_data_wal_mode_pct_enabled"
        case uiLoadInstrumentationEnabled = "ui_load_instrumentation_enabled_v2"
        case uiLoadInstrumentationBlocklist = "ui_load_instrumentation_blocklist"
        case uiLoadCaptureHostingControllers = "ui_load_instrumentation_hosting_controller_capture"
        case swiftUiViewInstrumentationEnabled = "swift_ui_view_instrumentation_enabled"

        case metricKitEnabledThreshold = "metrickit_v2_pct_enabled"
        case metricKitReportersEnabled = "metrickit_v2_reporters_enabled"
        case metricKitCrashSignalsEnabled = "metrickit_v2_crash_signals_enabled"
        case metricKitInternalMetricsCaptureEnabled = "metrickit_v2_internal_metrics_enabled"

        case ui
        enum UICodingKeys: String, CodingKey {
            case breadcrumbs
            case taps
        }

        case logLimits = "log"
        enum LogLimitsCodingKeys: String, CodingKey {
            case info = "info_limit"
            case warning = "warning_limit"
            case error = "error_limit"
        }

        case internalLogLimits = "internal_log_limits"
        enum InternalLogLimitsCodingKeys: String, CodingKey {
            case trace
            case debug
            case info
            case warning
            case error
        }

        case hangLimits = "hang_limits"
        enum HangLimitsCodingKeys: String, CodingKey {
            case hangPerSession = "hang_per_session"
            case samplesPerHang = "samples_per_hang"
            case reportsWatchdogEvents = "reports_watchdog_events"
        }

        case networkPayLoadCapture = "network_capture"
        case useLegacyUrlSessionProxy = "use_legacy_urlsession_proxy"
        case useNewStorageForSpanEvents = "use_new_storage_for_span_events"

        case userSession = "user_session"
        enum UserSessionCodingKeys: String, CodingKey {
            case maxDurationSeconds = "max_duration_seconds"
            case inactivityTimeoutSeconds = "inactivity_timeout_seconds"
        }
    }

    public init(from decoder: Decoder) throws {
        let defaultPayload = RemoteConfigPayload()

        // sdk enabled
        let rootContainer = try decoder.container(keyedBy: CodingKeys.self)
        sdkEnabledThreshold =
            try rootContainer.decodeIfPresent(
                Float.self,
                forKey: .sdkEnabledThreshold
            ) ?? defaultPayload.sdkEnabledThreshold

        // background session
        if rootContainer.contains(.background) {
            let backgroundContainer = try rootContainer.nestedContainer(
                keyedBy: CodingKeys.BackgroundCodingKeys.self,
                forKey: .background
            )
            backgroundSessionThreshold =
                try backgroundContainer.decodeIfPresent(
                    Float.self,
                    forKey: CodingKeys.BackgroundCodingKeys.threshold
                ) ?? defaultPayload.backgroundSessionThreshold
        } else {
            backgroundSessionThreshold = defaultPayload.backgroundSessionThreshold
        }

        // network span forwarding
        if rootContainer.contains(.networkSpansForwarding) {
            let networkSpansForwardingContainer = try rootContainer.nestedContainer(
                keyedBy: CodingKeys.NetworkSpansForwardingCodingKeys.self,
                forKey: .networkSpansForwarding
            )
            networkSpansForwardingThreshold =
                try networkSpansForwardingContainer.decodeIfPresent(
                    Float.self,
                    forKey: CodingKeys.NetworkSpansForwardingCodingKeys.threshold
                ) ?? defaultPayload.networkSpansForwardingThreshold
        } else {
            networkSpansForwardingThreshold = defaultPayload.networkSpansForwardingThreshold
        }

        // is wal mode enabled config
        walModeThreshold =
            try rootContainer.decodeIfPresent(
                Float.self,
                forKey: .walModeThreshold
            ) ?? defaultPayload.walModeThreshold

        // ui load instrumentation
        uiLoadInstrumentationEnabled =
            try rootContainer.decodeIfPresent(
                Bool.self,
                forKey: .uiLoadInstrumentationEnabled
            ) ?? defaultPayload.uiLoadInstrumentationEnabled

        // ui block list
        if let strArray = try rootContainer.decodeIfPresent(
            String.self,
            forKey: .uiLoadInstrumentationBlocklist
        )?.uppercased() {
            viewControllerClassNameBlocklist = strArray.components(separatedBy: ",")
        } else {
            viewControllerClassNameBlocklist = defaultPayload.viewControllerClassNameBlocklist
        }

        // hosting controllers capture
        uiInstrumentationCaptureHostingControllers =
            try rootContainer.decodeIfPresent(
                Bool.self,
                forKey: .uiLoadCaptureHostingControllers
            ) ?? defaultPayload.uiInstrumentationCaptureHostingControllers

        // SwiftUI View instrumentation
        swiftUiViewInstrumentationEnabled =
            try rootContainer.decodeIfPresent(
                Bool.self,
                forKey: .swiftUiViewInstrumentationEnabled
            ) ?? defaultPayload.swiftUiViewInstrumentationEnabled

        // span events
        if rootContainer.contains(.ui) {
            let uiContainer = try rootContainer.nestedContainer(
                keyedBy: CodingKeys.UICodingKeys.self,
                forKey: .ui
            )

            breadcrumbLimit =
                try uiContainer.decodeIfPresent(
                    Int.self,
                    forKey: CodingKeys.UICodingKeys.breadcrumbs
                ) ?? defaultPayload.breadcrumbLimit

            tapLimit =
                try uiContainer.decodeIfPresent(
                    Int.self,
                    forKey: CodingKeys.UICodingKeys.taps
                ) ?? defaultPayload.tapLimit
        } else {
            breadcrumbLimit = defaultPayload.breadcrumbLimit
            tapLimit = defaultPayload.tapLimit
        }

        // logs limit
        if rootContainer.contains(.logLimits) {
            let logsLimitsContainer = try rootContainer.nestedContainer(
                keyedBy: CodingKeys.LogLimitsCodingKeys.self,
                forKey: .logLimits
            )

            logsInfoLimit =
                try logsLimitsContainer.decodeIfPresent(
                    Int.self,
                    forKey: CodingKeys.LogLimitsCodingKeys.info
                ) ?? defaultPayload.logsInfoLimit

            logsWarningLimit =
                try logsLimitsContainer.decodeIfPresent(
                    Int.self,
                    forKey: CodingKeys.LogLimitsCodingKeys.warning
                ) ?? defaultPayload.logsWarningLimit

            logsErrorLimit =
                try logsLimitsContainer.decodeIfPresent(
                    Int.self,
                    forKey: CodingKeys.LogLimitsCodingKeys.error
                ) ?? defaultPayload.logsErrorLimit

        } else {
            logsInfoLimit = defaultPayload.logsInfoLimit
            logsWarningLimit = defaultPayload.logsWarningLimit
            logsErrorLimit = defaultPayload.logsErrorLimit
        }

        // hang limits
        if rootContainer.contains(.hangLimits) {
            let hangLimitsContainer = try rootContainer.nestedContainer(
                keyedBy: CodingKeys.HangLimitsCodingKeys.self,
                forKey: .hangLimits
            )

            hangLimitsHangPerSession =
                try hangLimitsContainer.decodeIfPresent(
                    UInt.self,
                    forKey: CodingKeys.HangLimitsCodingKeys.hangPerSession
                ) ?? defaultPayload.hangLimitsHangPerSession

            hangLimitsSamplesPerHang =
                try hangLimitsContainer.decodeIfPresent(
                    UInt.self,
                    forKey: CodingKeys.HangLimitsCodingKeys.samplesPerHang
                ) ?? defaultPayload.hangLimitsSamplesPerHang

            hangLimitsReportsWatchdogEvents =
                try hangLimitsContainer.decodeIfPresent(
                    Bool.self,
                    forKey: CodingKeys.HangLimitsCodingKeys.reportsWatchdogEvents
                ) ?? defaultPayload.hangLimitsReportsWatchdogEvents
        } else {
            hangLimitsHangPerSession = defaultPayload.hangLimitsHangPerSession
            hangLimitsSamplesPerHang = defaultPayload.hangLimitsSamplesPerHang
            hangLimitsReportsWatchdogEvents = defaultPayload.hangLimitsReportsWatchdogEvents
        }

        // internal logs limit
        if rootContainer.contains(.internalLogLimits) {
            let internalLogsLimitsContainer = try rootContainer.nestedContainer(
                keyedBy: CodingKeys.InternalLogLimitsCodingKeys.self,
                forKey: .internalLogLimits
            )

            internalLogsTraceLimit =
                try internalLogsLimitsContainer.decodeIfPresent(
                    Int.self,
                    forKey: CodingKeys.InternalLogLimitsCodingKeys.trace
                ) ?? defaultPayload.internalLogsTraceLimit

            internalLogsDebugLimit =
                try internalLogsLimitsContainer.decodeIfPresent(
                    Int.self,
                    forKey: CodingKeys.InternalLogLimitsCodingKeys.debug
                ) ?? defaultPayload.internalLogsDebugLimit

            internalLogsInfoLimit =
                try internalLogsLimitsContainer.decodeIfPresent(
                    Int.self,
                    forKey: CodingKeys.InternalLogLimitsCodingKeys.info
                ) ?? defaultPayload.internalLogsInfoLimit

            internalLogsWarningLimit =
                try internalLogsLimitsContainer.decodeIfPresent(
                    Int.self,
                    forKey: CodingKeys.InternalLogLimitsCodingKeys.warning
                ) ?? defaultPayload.internalLogsWarningLimit

            internalLogsErrorLimit =
                try internalLogsLimitsContainer.decodeIfPresent(
                    Int.self,
                    forKey: CodingKeys.InternalLogLimitsCodingKeys.error
                ) ?? defaultPayload.internalLogsErrorLimit

        } else {
            internalLogsTraceLimit = defaultPayload.internalLogsTraceLimit
            internalLogsDebugLimit = defaultPayload.internalLogsDebugLimit
            internalLogsInfoLimit = defaultPayload.internalLogsInfoLimit
            internalLogsWarningLimit = defaultPayload.internalLogsWarningLimit
            internalLogsErrorLimit = defaultPayload.internalLogsErrorLimit
        }

        // network payload capture
        networkPayloadCaptureRules =
            (try? rootContainer.decodeIfPresent(
                [NetworkPayloadCaptureRule].self,
                forKey: .networkPayLoadCapture
            )) ?? defaultPayload.networkPayloadCaptureRules

        // metric kit
        metricKitEnabledThreshold =
            try rootContainer.decodeIfPresent(
                Float.self,
                forKey: .metricKitEnabledThreshold
            ) ?? defaultPayload.metricKitEnabledThreshold

        metricKitInternalMetricsCaptureEnabled =
            try rootContainer.decodeIfPresent(
                Bool.self,
                forKey: .metricKitInternalMetricsCaptureEnabled
            ) ?? defaultPayload.metricKitInternalMetricsCaptureEnabled

        if let strArray = try rootContainer.decodeIfPresent(
            String.self,
            forKey: .metricKitReportersEnabled
        )?.uppercased() {
            metricKitCrashCaptureEnabled = strArray.contains("CRASH")
            metricKitHangCaptureEnabled = strArray.contains("HANG")
        } else {
            metricKitCrashCaptureEnabled = defaultPayload.metricKitCrashCaptureEnabled
            metricKitHangCaptureEnabled = defaultPayload.metricKitHangCaptureEnabled
        }

        if let strArray = try rootContainer.decodeIfPresent(
            String.self,
            forKey: .metricKitCrashSignalsEnabled
        )?.uppercased() {
            metricKitCrashSignals = strArray.components(separatedBy: ",")
        } else {
            metricKitCrashSignals = defaultPayload.metricKitCrashSignals
        }

        // use old url session proxy
        useLegacyUrlSessionProxy =
            try rootContainer.decodeIfPresent(
                Bool.self,
                forKey: .useLegacyUrlSessionProxy
            ) ?? defaultPayload.useLegacyUrlSessionProxy

        // use new storage for span events
        useNewStorageForSpanEvents =
            try rootContainer.decodeIfPresent(
                Bool.self,
                forKey: .useNewStorageForSpanEvents
            ) ?? defaultPayload.useNewStorageForSpanEvents

        // user session
        if rootContainer.contains(.userSession) {
            let userSessionContainer = try rootContainer.nestedContainer(
                keyedBy: CodingKeys.UserSessionCodingKeys.self,
                forKey: .userSession
            )

            let rawMax =
                (try? userSessionContainer.decodeIfPresent(
                    TimeInterval.self,
                    forKey: CodingKeys.UserSessionCodingKeys.maxDurationSeconds
                )) ?? defaultPayload.userSessionMaxDurationSeconds

            let rawInactivity =
                (try? userSessionContainer.decodeIfPresent(
                    TimeInterval.self,
                    forKey: CodingKeys.UserSessionCodingKeys.inactivityTimeoutSeconds
                )) ?? defaultPayload.userSessionInactivityTimeoutSeconds

            let validated = Self.validateUserSession(max: rawMax, inactivity: rawInactivity)
            userSessionMaxDurationSeconds = validated.max
            userSessionInactivityTimeoutSeconds = validated.inactivity
        } else {
            userSessionMaxDurationSeconds = defaultPayload.userSessionMaxDurationSeconds
            userSessionInactivityTimeoutSeconds = defaultPayload.userSessionInactivityTimeoutSeconds
        }
    }

    /// Validates the user-session config values per spec §3.
    /// 1. Per-field range check: out-of-range falls back to the default for that field.
    /// 2. Cross-field check: if `inactivity > max` after step 1, force `inactivity = 30 * 60`.
    static func validateUserSession(
        max: TimeInterval,
        inactivity: TimeInterval
    ) -> (max: TimeInterval, inactivity: TimeInterval) {
        // valid ranges
        let maxRange: ClosedRange<TimeInterval> = 3600...86400  // 1h–24h
        let inactivityRange: ClosedRange<TimeInterval> = 30...86400  // 30s–24h

        // defaults
        let defaultMax: TimeInterval = 12 * 3600
        let defaultInactivity: TimeInterval = 30 * 60

        let validatedMax = maxRange.contains(max) ? max : defaultMax
        var validatedInactivity = inactivityRange.contains(inactivity) ? inactivity : defaultInactivity

        // cross-field: inactivity must be <= max; if not, force the default inactivity (30 min).
        // Safe because the smallest allowed `max` (1h) is always >= 30 min.
        if validatedInactivity > validatedMax {
            validatedInactivity = defaultInactivity
        }

        return (validatedMax, validatedInactivity)
    }

    // defaults
    public init() {
        sdkEnabledThreshold = 100.0
        backgroundSessionThreshold = 0.0
        networkSpansForwardingThreshold = 0.0
        walModeThreshold = 100.0

        uiLoadInstrumentationEnabled = true
        viewControllerClassNameBlocklist = []
        uiInstrumentationCaptureHostingControllers = false
        swiftUiViewInstrumentationEnabled = true

        metricKitEnabledThreshold = 0.0
        metricKitCrashCaptureEnabled = false
        metricKitCrashSignals = [CrashSignal.SIGKILL.stringValue]
        metricKitHangCaptureEnabled = false
        metricKitInternalMetricsCaptureEnabled = false

        breadcrumbLimit = 100
        tapLimit = 80

        logsInfoLimit = 100
        logsWarningLimit = 200
        logsErrorLimit = 500

        internalLogsTraceLimit = 0
        internalLogsDebugLimit = 0
        internalLogsInfoLimit = 0
        internalLogsWarningLimit = 0
        internalLogsErrorLimit = 3

        hangLimitsHangPerSession = 200
        hangLimitsSamplesPerHang = 0
        hangLimitsReportsWatchdogEvents = false

        networkPayloadCaptureRules = []
        useLegacyUrlSessionProxy = false
        useNewStorageForSpanEvents = false

        userSessionMaxDurationSeconds = 12 * 3600
        userSessionInactivityTimeoutSeconds = 30 * 60
    }
}
