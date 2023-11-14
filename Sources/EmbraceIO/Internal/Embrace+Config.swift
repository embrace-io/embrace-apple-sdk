//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceConfig

extension Embrace {
    static func createConfig(options: Embrace.Options, deviceId: String) -> EmbraceConfig {
        let configOptions = EmbraceConfig.Options(
            apiBaseUrl: options.endpoints.configBaseURL,
            queue: DispatchQueue(label: "com.embrace.config"),
            appId: options.appId,
            deviceId: deviceId,
            osVersion: "16.0", // TODO: Do this properly!
            sdkVersion: EmbraceMeta.sdkVersion,
            appVersion: "1.0", // TODO: Do this properly!
            userAgent: EmbraceMeta.userAgent
        )

        return EmbraceConfig(options: configOptions)
    }
}
