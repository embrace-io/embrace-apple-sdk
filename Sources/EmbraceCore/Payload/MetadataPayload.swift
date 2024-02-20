//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

struct MetadataPayload: Codable {
    var locale: String?
    var timezone_description: String?
    var personas = [String]()
    var username: String?
    var email: String?
    var user_id: String?
}
