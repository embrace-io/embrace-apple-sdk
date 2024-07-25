//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

// swiftlint:disable nesting

struct RemoteConfigPayload: Decodable, Equatable {
    var sdkEnabledThreshold: Float
    var backgroundSessionThreshold: Float
    var networkSpansForwardingThreshold: Float

    var internalLogsTraceLimit: Int
    var internalLogsDebugLimit: Int
    var internalLogsInfoLimit: Int
    var internalLogsWarningLimit: Int
    var internalLogsErrorLimit: Int

    enum CodingKeys: String, CodingKey {
        case sdkEnabledThreshold = "threshold"

        case background
        enum BackgroundCodingKeys: String, CodingKey {
            case threshold
        }

        case networkSpansForwarding = "network_span_forwarding"
        enum NetworkSpansForwardingCodigKeys: String, CodingKey {
            case threshold = "pct_enabled"
        }

        case internalLogLimits = "internal_log_limits"
        enum InternalLogLimitsCodingKeys: String, CodingKey {
            case trace
            case debug
            case info
            case warning
            case error
        }
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
                keyedBy: CodingKeys.NetworkSpansForwardingCodigKeys.self,
                forKey: .networkSpansForwarding
            )
            networkSpansForwardingThreshold = try networkSpansForwardingContainer.decodeIfPresent(
                Float.self,
                forKey: CodingKeys.NetworkSpansForwardingCodigKeys.threshold
            ) ?? defaultPayload.networkSpansForwardingThreshold
        } else {
            networkSpansForwardingThreshold = defaultPayload.networkSpansForwardingThreshold
        }

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
    }

    // defaults
    public init() {
        sdkEnabledThreshold = 100.0
        backgroundSessionThreshold = 0.0
        networkSpansForwardingThreshold = 0.0

        internalLogsTraceLimit = 0
        internalLogsDebugLimit = 0
        internalLogsInfoLimit = 0
        internalLogsWarningLimit = 0
        internalLogsErrorLimit = 3
    }
}

// swiftlint:enable nesting
