//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceObjCUtilsInternal
import EmbraceConfigInternal
import EmbraceCommonInternal
import EmbraceConfiguration

extension Embrace {

    /// Creates `EmbraceConfig` object
    static func createConfig(
        options: Embrace.Options,
        deviceId: DeviceIdentifier
    ) -> EmbraceConfig {
        return EmbraceConfig(
            configurable: runtimeConfiguration(from: options, deviceId: deviceId),
            options: .init(),
            notificationCenter: Embrace.notificationCenter,
            logger: Embrace.logger
        )
    }

    private static func runtimeConfiguration(
        from options: Embrace.Options,
        deviceId: DeviceIdentifier
    ) -> EmbraceConfigurable {
        if let configImpl = options.runtimeConfiguration {
            return configImpl
        }

        guard let configBaseURL = options.endpoints?.configBaseURL else {
            return DefaultConfig()
        }

        guard let appId = options.appId else {
            return DefaultConfig()
        }

        let options = RemoteConfig.Options(
            apiBaseUrl: configBaseURL,
            queue: DispatchQueue(label: "com.embrace.config"),
            appId: appId,
            deviceId: deviceId,
            osVersion: EMBDevice.appVersion ?? "",
            sdkVersion: EmbraceMeta.sdkVersion,
            appVersion: EMBDevice.operatingSystemVersion,
            userAgent: EmbraceMeta.userAgent
        )

        let usedDigits = UInt(6)
        return RemoteConfig(
            options: options,
            logger: logger
        )
    }
}
