//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceObjCUtilsInternal
import EmbraceConfigInternal
import EmbraceCommonInternal

extension Embrace {

    /// Creates `EmbraceConfig` object
    static func createConfig(
        options: Embrace.Options,
        deviceId: String
    ) -> EmbraceConfig? {

        guard let appId = options.appId else {
            return nil
        }

        guard let endpoints = options.endpoints else {
            return nil
        }

        let configOptions = EmbraceConfig.Options(
            apiBaseUrl: endpoints.configBaseURL,
            queue: DispatchQueue(label: "com.embrace.config"),
            appId: appId,
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
