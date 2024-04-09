//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

// swiftlint:disable nesting

struct RemoteConfigPayload: Decodable {
    var sdkEnabledThreshold: Float
    var backgroundSessionThreshold: Float
    var networkSpansForwardingThreshold: Float

    enum CodingKeys: String, CodingKey {
        case sdkEnabledThreshold = "threshold"
        case background
        case networkSpansForwarding = "network_span_forwarding"

        enum BackgroundCodingKeys: String, CodingKey {
            case threshold
        }

        enum NetworkSpansForwardingCodigKeys: String, CodingKey {
            case threshold = "pct_enabled"
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
    }

    // defaults
    public init() {
        sdkEnabledThreshold = 100.0
        backgroundSessionThreshold = 0.0
        networkSpansForwardingThreshold = 0.0
    }
}

// swiftlint:enable nesting
