//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceIO

extension BrandGameApp {
#if DEBUG
    var embraceOptions: EmbraceOptions {
        return .init(
            appId: "stage",
            appGroupId: nil,
            platform: .iOS
        )!
    }
#else
    var embraceOptions: EmbraceOptions {

        return .init(
            appId: "myApp",
            appGroupId: nil,
            platform: .iOS
        )
    }
#endif
}
