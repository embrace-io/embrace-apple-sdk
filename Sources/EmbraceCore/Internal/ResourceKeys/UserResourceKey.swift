//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceStorageInternal
#endif

enum UserResourceKey: String, CaseIterable {
    case name = "emb.user.username"
    case email = "emb.user.email"
    case identifier = "emb.user.identifier"

    static var allValues: [String] {
        allCases.map(\.rawValue)
    }
}
