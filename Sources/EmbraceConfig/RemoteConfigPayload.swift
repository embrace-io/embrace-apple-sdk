//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

// swiftlint:disable nesting

struct RemoteConfigPayload: Decodable {
    var sdkEnabledThreshold: Float
    var backgroundSessionThreshold: Float

    enum CodingKeys: String, CodingKey {
        case sdkEnabledThreshold = "threshold"
        case background

        enum BackgroundCodingKeys: String, CodingKey {
            case threshold
        }
    }

    public init(from decoder: Decoder) throws {
        let defaultPayload = RemoteConfigPayload()

        let rootContainer = try decoder.container(keyedBy: CodingKeys.self)
        sdkEnabledThreshold = try rootContainer.decodeIfPresent(
            Float.self,
            forKey: .sdkEnabledThreshold
        ) ?? defaultPayload.sdkEnabledThreshold

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
    }

    // defaults
    public init() {
        sdkEnabledThreshold = 100.0
        backgroundSessionThreshold = 0.0
    }
}

// swiftlint:enable nesting
