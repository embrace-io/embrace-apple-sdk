//
//  WWDCData.swift
//  tvosTestApp
//
//

import Foundation

struct WWDCData: Decodable {
    let updated: String
    let source: String
    let schema: Int
    var sessions: [WWDCSession]
    var events: [WWDCEvent]
    
    enum CodingKeys: CodingKey {
        case updated
        case source
        case schema
        case sessions
        case events
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.updated = try container.decode(String.self, forKey: .updated)
        self.source = try container.decode(String.self, forKey: .source)
        self.schema = try container.decode(Int.self, forKey: .schema)
        self.sessions = try container.decode([WWDCSession].self, forKey: .sessions)
        self.events = try container.decode([WWDCEvent].self, forKey: .events)
    }
}
