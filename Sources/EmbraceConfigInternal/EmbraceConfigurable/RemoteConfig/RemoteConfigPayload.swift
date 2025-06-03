//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceConfiguration
import EmbraceCommonInternal
#endif

// swiftlint:disable nesting

public struct RemoteConfigPayload: Decodable, Equatable {
    var sdkEnabledThreshold: Float
    var backgroundSessionThreshold: Float
    var networkSpansForwardingThreshold: Float
    var uiLoadInstrumentationEnabled: Bool

    var metricKitEnabledThreshold: Float
    var metricKitCrashCaptureEnabled: Bool
    var metricKitCrashSignals: [String]
    var metricKitHangCaptureEnabled: Bool

    var swiftUiViewInstrumentationEnabled: Bool
    
    var internalLogsTraceLimit: Int
    var internalLogsDebugLimit: Int
    var internalLogsInfoLimit: Int
    var internalLogsWarningLimit: Int
    var internalLogsErrorLimit: Int

    var networkPayloadCaptureRules: [NetworkPayloadCaptureRule]

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

        case uiLoadInstrumentationEnabled = "ui_load_instrumentation_enabled_v2"
        case swiftUiViewInstrumentationEnabled = "swift_ui_view_instrumentation_enabled"

        case metricKitEnabledThreshold = "metrickit_v2_pct_enabled"
        case metricKitReportersEnabled = "metrickit_v2_reporters_enabled"
        case metricKitCrashSignalsEnabled = "metrickit_v2_crash_signals_enabled"

        case internalLogLimits = "internal_log_limits"
        enum InternalLogLimitsCodingKeys: String, CodingKey {
            case trace
            case debug
            case info
            case warning
            case error
        }

        case networkPayLoadCapture = "network_capture"
    }

    public init(from decoder: Decoder) throws {
        let defaultPayload = RemoteConfigPayload()

        // sdk enabled
        let rootContainer = try decoder.container(keyedBy: CodingKeys.self)
        sdkEnabledThreshold = try rootContainer.decodeIfPresent(
            Float.self,
            forKey: .sdkEnabledThreshold
        ) ?? defaultPayload.sdkEnabledThreshold

        // background session
        if rootContainer.contains(.background) {
            let backgroundContainer = try rootContainer.nestedContainer(
                keyedBy: CodingKeys.BackgroundCodingKeys.self,
                forKey: .background
            )
            backgroundSessionThreshold = try backgroundContainer.decodeIfPresent(
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
            networkSpansForwardingThreshold = try networkSpansForwardingContainer.decodeIfPresent(
                Float.self,
                forKey: CodingKeys.NetworkSpansForwardingCodingKeys.threshold
            ) ?? defaultPayload.networkSpansForwardingThreshold
        } else {
            networkSpansForwardingThreshold = defaultPayload.networkSpansForwardingThreshold
        }

        // ui load instrumentation
        uiLoadInstrumentationEnabled = try rootContainer.decodeIfPresent(
            Bool.self,
            forKey: .uiLoadInstrumentationEnabled
        ) ?? defaultPayload.uiLoadInstrumentationEnabled
        
        // SwiftUI View instrumentation
        swiftUiViewInstrumentationEnabled = try rootContainer.decodeIfPresent(
            Bool.self,
            forKey: .swiftUiViewInstrumentationEnabled
        ) ?? defaultPayload.swiftUiViewInstrumentationEnabled
        
        // internal logs limit
        if rootContainer.contains(.internalLogLimits) {
            let internalLogsLimitsContainer = try rootContainer.nestedContainer(
                keyedBy: CodingKeys.InternalLogLimitsCodingKeys.self,
                forKey: .internalLogLimits
            )

            internalLogsTraceLimit = try internalLogsLimitsContainer.decodeIfPresent(
                Int.self,
                forKey: CodingKeys.InternalLogLimitsCodingKeys.trace
            ) ?? defaultPayload.internalLogsTraceLimit

            internalLogsDebugLimit = try internalLogsLimitsContainer.decodeIfPresent(
                Int.self,
                forKey: CodingKeys.InternalLogLimitsCodingKeys.debug
            ) ?? defaultPayload.internalLogsDebugLimit

            internalLogsInfoLimit = try internalLogsLimitsContainer.decodeIfPresent(
                Int.self,
                forKey: CodingKeys.InternalLogLimitsCodingKeys.info
            ) ?? defaultPayload.internalLogsInfoLimit

            internalLogsWarningLimit = try internalLogsLimitsContainer.decodeIfPresent(
                Int.self,
                forKey: CodingKeys.InternalLogLimitsCodingKeys.warning
            ) ?? defaultPayload.internalLogsWarningLimit

            internalLogsErrorLimit = try internalLogsLimitsContainer.decodeIfPresent(
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
        networkPayloadCaptureRules = (try? rootContainer.decodeIfPresent(
            [NetworkPayloadCaptureRule].self,
            forKey: .networkPayLoadCapture
        )) ?? defaultPayload.networkPayloadCaptureRules

        // metric kit
        metricKitEnabledThreshold = try rootContainer.decodeIfPresent(
            Float.self,
            forKey: .metricKitEnabledThreshold
        ) ?? defaultPayload.metricKitEnabledThreshold

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
    }

    // defaults
    public init() {
        sdkEnabledThreshold = 100.0
        backgroundSessionThreshold = 0.0
        networkSpansForwardingThreshold = 0.0
        uiLoadInstrumentationEnabled = true

        metricKitEnabledThreshold = 0.0
        metricKitCrashCaptureEnabled = false
        metricKitCrashSignals = [CrashSignal.SIGKILL.stringValue]
        metricKitHangCaptureEnabled = false

        swiftUiViewInstrumentationEnabled = true
        
        internalLogsTraceLimit = 0
        internalLogsDebugLimit = 0
        internalLogsInfoLimit = 0
        internalLogsWarningLimit = 0
        internalLogsErrorLimit = 3

        networkPayloadCaptureRules = []
    }
}

// swiftlint:enable nesting
