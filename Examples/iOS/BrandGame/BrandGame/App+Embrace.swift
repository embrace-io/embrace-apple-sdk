//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceIO

extension BrandGameApp {
#if DEBUG
    var embraceOptions: Embrace.Options {
        return .init(
            appId: "AK5HV",
            appGroupId: nil,
            platform: .iOS
        )
    }
#else
    var embraceOptions: Embrace.Options {

        return .init(
            appId: "kj9hd",
            appGroupId: nil,
            platform: .iOS
        )
    }
#endif
}
