//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceStorageInternal

enum UserResourceKey: String, CaseIterable {
    case name = "emb.user.username"
    case email = "emb.user.email"
    case identifier = "emb.user.identifier"

    static var allValues: [String] {
        allCases.map(\.rawValue)
    }
}
