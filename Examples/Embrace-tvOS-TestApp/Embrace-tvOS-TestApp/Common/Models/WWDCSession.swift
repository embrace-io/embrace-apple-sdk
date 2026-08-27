//
//  WWDCSession.swift
//  tvosTestApp
//
//

import CoreGraphics
import Foundation

struct WWDCSession: Decodable, Encodable {
    let id: String
    let title: String
    let description: String?
    let eventId: String
    let eventContentId: String
    let year: Int
    let topic: String
    let speakers: [String]?
    let platforms: [String]?
    let media: WWDCMedia?

    enum CodingKeys: CodingKey {
        case id
        case title
        case description
        case eventId
        case eventContentId
        case year
        case topic
        case speakers
        case platforms
        case media
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.eventId = try container.decode(String.self, forKey: .eventId)
        self.eventContentId = try container.decode(String.self, forKey: .eventContentId)
        self.year = try container.decode(Int.self, forKey: .year)
        self.topic = try container.decode(String.self, forKey: .topic)
        self.speakers = try container.decodeIfPresent([String].self, forKey: .speakers)
        self.platforms = try container.decodeIfPresent([String].self, forKey: .platforms)
        self.media = try container.decodeIfPresent(WWDCMedia.self, forKey: .media)
    }
}

extension WWDCSession: Hashable {}

extension WWDCSession {
    static var mockData: Data {
        """
        {
          "id": "1234",
          "title": "Mock Video Title",
          "description": "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
          "eventId": "Mock_Event_Id",
          "eventContentId": "101",
          "year": 2025,
          "topic": "iOS",
          "speakers": ["John Doe", "John Appleseed"],
          "platforms": ["iOS", "Mac OS", "tvOS"],
          "media": {
            "duration": 1234
          }
        }
        """.data(using: .utf8, allowLossyConversion: false)!
    }
}
