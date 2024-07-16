//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorageInternal

struct MetadataPayload: Codable {
    var locale: String?
    var timezoneDescription: String?
    var personas = [String]()
    var username: String?
    var email: String?
    var userId: String?

    enum CodingKeys: String, CodingKey {
        case locale, personas, username, email
        case timezoneDescription = "timezone_description"
        case userId = "user_id"
    }

    init(from metadata: [MetadataRecord]) {
        metadata.forEach { record in
            if let key = UserResourceKey(rawValue: record.key) {
                switch key {
                case .name:
                    self.username = record.stringValue
                case .email:
                    self.email = record.stringValue
                case .identifier:
                    self.userId = record.stringValue
                }
            }

            if let key = DeviceResourceKey(rawValue: record.key) {
                switch key {
                case .locale:
                    self.locale = record.stringValue
                case .timezone:
                    self.timezoneDescription = record.stringValue
                default:
                    break
                }
            }

            if record.type == .personaTag {
                personas.append(record.key)
            }
        }
    }
}
