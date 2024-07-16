//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import OpenTelemetryApi
import EmbraceObjCUtilsInternal

class AppInfoCaptureService: ResourceCaptureService {

    override func onStart() {
        // bundle version
        addResource(
            key: AppResourceKey.bundleVersion.rawValue,
            value: .string(EMBDevice.bundleVersion)
        )

        // environment
        addResource(
            key: AppResourceKey.environment.rawValue,
            value: .string(EMBDevice.environment)
        )

        // environment detail
        addResource(
            key: AppResourceKey.detailedEnvironment.rawValue,
            value: .string(EMBDevice.environmentDetail)
        )

        // framework
        addResource(
            key: AppResourceKey.framework.rawValue,
            value: .int(Embrace.client?.options.platform.frameworkId ?? -1)
        )

        // sdk version
        addResource(
            key: AppResourceKey.sdkVersion.rawValue,
            value: .string(EmbraceMeta.sdkVersion)
        )

        // app version
        if let appVersion = EMBDevice.appVersion {
            addResource(
                key: AppResourceKey.appVersion.rawValue,
                value: .string(appVersion)
            )
        }

        // build UUID
        if let buildUUID = EMBDevice.buildUUID {
            addResource(
                key: AppResourceKey.buildID.rawValue,
                value: .string(buildUUID.withoutHyphen)
            )
        }

        // process identifier
        addResource(
            key: AppResourceKey.processIdentifier.rawValue,
            value: .string(ProcessIdentifier.current.hex)
        )
    }
}
