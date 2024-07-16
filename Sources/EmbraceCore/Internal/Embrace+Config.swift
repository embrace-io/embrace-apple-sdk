//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceObjCUtilsInternal
import EmbraceConfigInternal
import EmbraceCommonInternal

extension Embrace {
    static func createConfig(
        options: Embrace.Options,
        deviceId: String
    ) -> EmbraceConfig {

        let configOptions = EmbraceConfig.Options(
            apiBaseUrl: options.endpoints.configBaseURL,
            queue: DispatchQueue(label: "com.embrace.config"),
            appId: options.appId,
            deviceId: deviceId,
            osVersion: EMBDevice.appVersion ?? "",
            sdkVersion: EmbraceMeta.sdkVersion,
            appVersion: EMBDevice.operatingSystemVersion,
            userAgent: EmbraceMeta.userAgent
        )

        return EmbraceConfig(
            options: configOptions,
            notificationCenter: Embrace.notificationCenter,
            logger: Embrace.logger
        )
    }
}
