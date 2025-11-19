//
//  WWDCSession.swift
//  tvosTestApp
//
//

import Foundation

struct WWDCSession: Decodable {
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
