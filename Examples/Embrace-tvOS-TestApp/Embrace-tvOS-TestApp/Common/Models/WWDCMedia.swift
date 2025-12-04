//
//  WWDCMedia.swift
//  tvosTestApp
//
//

import Foundation

struct WWDCMedia: Codable {
    let duration: Int?
    let streamUrl: String?
    let streamState: String?

    var containsStreamingMedia: Bool {
        streamUrl != nil && streamState == "available"
    }

    enum CodingKeys: String, CodingKey {
        case duration
        case streamUrl = "streamHLS"
        case streamState = "streamHLS_state"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        self.streamUrl = try container.decodeIfPresent(String.self, forKey: .streamUrl)
        self.streamState = try container.decodeIfPresent(String.self, forKey: .streamState)
    }
}

extension WWDCMedia: Hashable {}
