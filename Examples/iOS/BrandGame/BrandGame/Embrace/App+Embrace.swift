//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceIO

extension BrandGameApp {
#if DEBUG
    // https://dash.embrace.io/app/AK5HV
    var embraceOptions: Embrace.Options {
        let appId = "AK5HV"
        if let options = Embrace.Endpoints.fromInfoPlist() {
            return .init(
                appId: appId,
                appGroupId: nil,
                platform: .iOS,
                endpoints: options
            )
        }
        return .init(appId: appId)
    }
#else
    // https://dash.embrace.io/app/kj9hd
    var embraceOptions: Embrace.Options {
        return .init(
            appId: "kj9hd",
            appGroupId: nil,
            platform: .iOS
        )
    }
#endif
}
