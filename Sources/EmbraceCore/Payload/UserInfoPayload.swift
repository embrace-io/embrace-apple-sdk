//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorageInternal

struct UserInfoPayload: Codable {

    var username: String?
    var identifier: String?
    var email: String?

    enum CodingKeys: String, CodingKey {
        case username = "un"
        case identifier = "id"
        case email = "em"
    }

    init(with properties: [MetadataRecord]) {
        properties.forEach { property in
            guard let key: UserResourceKey = UserResourceKey(rawValue: property.key) else {
                return
            }
            let value = property.stringValue

            switch key {
            case .name:
                username = value
            case .identifier:
                identifier = value
            case .email:
                email = value
            }
        }
    }
}
