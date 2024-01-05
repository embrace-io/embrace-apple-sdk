//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorage

struct UserInfoPayload: Codable {

    var username: String?
    var identifier: String?
    var email: String?

    enum CodingKeys: String, CodingKey {
        case username = "un"
        case identifier = "id"
        case email = "em"
    }

    init(with resources: [ResourceRecord]) {
        resources.forEach { resource in
            guard let key: UserResourceKey = UserResourceKey(rawValue: resource.key) else {
                return
            }

            switch key {
            case .username:
                username = resource.stringValue
            case .identifier:
                identifier = resource.stringValue
            case .email:
                email = resource.stringValue
            }
        }
    }
}
