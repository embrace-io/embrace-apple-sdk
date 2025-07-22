//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

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

    init(from metadata: [EmbraceMetadata]) {
        metadata.forEach { record in
            if let key = UserResourceKey(rawValue: record.key) {
                switch key {
                case .name:
                    self.username = record.value
                case .email:
                    self.email = record.value
                case .identifier:
                    self.userId = record.value
                }
            }

            if let key = DeviceResourceKey(rawValue: record.key) {
                switch key {
                case .locale:
                    self.locale = record.value
                case .timezone:
                    self.timezoneDescription = record.value
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
