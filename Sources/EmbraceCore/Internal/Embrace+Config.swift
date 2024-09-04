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
        deviceId: DeviceIdentifier
    ) -> EmbraceConfig {

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
            configurable: runtimeConfiguration(from: options, deviceId: deviceId),
            options: configOptions,
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

        let options = RemoteConfigFetcher.Options(
            apiBaseUrl: options.endpoints.configBaseURL,
            queue: DispatchQueue(label: "com.embrace.config"),
            appId: options.appId,
            deviceId: deviceId,
            osVersion: EMBDevice.appVersion ?? "",
            sdkVersion: EmbraceMeta.sdkVersion,
            appVersion: EMBDevice.operatingSystemVersion,
            userAgent: EmbraceMeta.userAgent
        )

        let fetcher = RemoteConfigFetcher(options: options, logger: logger)
        return RemoteConfig(
            fetcher: fetcher,
            deviceIdHexValue: deviceId.intValue(digitCount: 6)
        )
    }
}

extension DeviceIdentifier {
    func intValue(digitCount: Int) -> UInt64 {
        var deviceIdHexValue: UInt64 = UInt64.max // defaults to everything disabled

        let hexValue = hex
        if hexValue.count >= digitCount {
            deviceIdHexValue = UInt64.init(hexValue.suffix(digitCount), radix: 16) ?? .max
        }

        return deviceIdHexValue
    }
}
