//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceStorage

enum UserResourceKey: String, CaseIterable {
    case email = "emb.user.email"
    case username = "emb.user.username"
    case identifier = "emb.user.identifier"

    static var allValues: [String] {
        allCases.map(\.rawValue)
    }
}
