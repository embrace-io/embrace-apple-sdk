//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    @_implementationOnly import EmbraceObjCUtilsInternal
    import EmbraceConfigInternal
    import EmbraceCommonInternal
    import EmbraceConfiguration
#endif

extension Embrace {

    /// Creates `EmbraceConfig` object
    static func createConfig(
        options: Embrace.Options,
        deviceId: EmbraceIdentifier
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
        deviceId: EmbraceIdentifier
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

        let cacheLocation = EmbraceFileSystem.configDirectoryURL(
            partitionIdentifier: appId,
            appGroupId: options.appGroupId
        )

        let options = RemoteConfig.Options(
            apiBaseUrl: configBaseURL,
            queue: DispatchQueue(label: "com.embrace.config"),
            appId: appId,
            deviceId: deviceId,
            osVersion: EMBDevice.appVersion ?? "",
            sdkVersion: EmbraceMeta.sdkVersion,
            appVersion: EMBDevice.operatingSystemVersion,
            userAgent: EmbraceMeta.userAgent,
            cacheLocation: cacheLocation
        )

        return RemoteConfig(
            options: options,
            logger: logger
        )
    }
}
