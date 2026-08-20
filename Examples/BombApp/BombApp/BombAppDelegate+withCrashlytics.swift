//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceIO

extension BombAppDelegate {
    #if DEBUG
        // https://dash.embrace.io/app/dcdt4
        var embraceOptions: EmbraceIO.Options {
            return .withAppId(
                "dcdt4",
                platform: .default,
                endpoints: EmbraceEndpoints.fromInfoPlist(),
                crashReporter: .crashlytics,
                logLevel: .debug
            )
        }
    #else
        // https://dash.embrace.io/app/kj9hd
        var embraceOptions: EmbraceIO.Options {
            return .withAppId(
                "kj9hd",
                platform: .default,
                crashReporter: .crashlytics
            )
        }
    #endif
}
