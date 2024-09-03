//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceIO
import EmbraceCrashlyticsSupport

extension BombAppDelegate {
#if DEBUG
    // https://dash.embrace.io/app/AK5HV
    var embraceOptions: Embrace.Options {
        return .init(
            appId: "AK5HV",
            appGroupId: nil,
            platform: .default,
            endpoints: Embrace.Endpoints.fromInfoPlist(),
            captureServices: .automatic,
            crashReporter: CrashlyticsReporter(),
            logLevel: .debug
        )
    }
#else
    // https://dash.embrace.io/app/kj9hd
    var embraceOptions: Embrace.Options {
        return .init(
            appId: "kj9hd",
            appGroupId: nil,
            platform: .default,
            captureServices: .automatic,
            crashReporter: CrashlyticsReporter()
        )
    }
#endif
}
