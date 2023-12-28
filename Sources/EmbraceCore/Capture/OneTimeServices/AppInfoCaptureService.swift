//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceObjCUtils

@objc public class AppInfoCaptureService: NSObject, CaptureService {
    typealias Keys = AppResourceKey

    let resourceHandler: CaptureServiceResourceHandlerType

    init(resourceHandler: CaptureServiceResourceHandlerType = CaptureServiceResourceHandler()) {
        self.resourceHandler = resourceHandler
    }

    public func start() {
        let bundleVersion = EMBDevice.bundleVersion
        let environment = EMBDevice.environment
        let environmentDetail = EMBDevice.environmentDetail
        var framework = Embrace.client?.options.platform.frameworkId
        var sdkVersion = EmbraceMeta.sdkVersion
        let appVersion = EMBDevice.appVersion

        do {
            try resourceHandler.addResource(key: Keys.bundleVersion.rawValue, value: bundleVersion)
            try resourceHandler.addResource(key: Keys.environment.rawValue, value: environment)
            try resourceHandler.addResource(key: Keys.detailedEnvironment.rawValue, value: environmentDetail)
            try resourceHandler.addResource(key: Keys.framework.rawValue, value: framework ?? -1)
            try resourceHandler.addResource(key: Keys.sdkVersion.rawValue, value: sdkVersion)
            try resourceHandler.addResource(key: Keys.appVersion.rawValue, value: appVersion ?? "N/A")
        } catch let e {
            ConsoleLog.error("Failed to capture app info metadata \(e.localizedDescription)")
        }
    }

    public func stop() {}
}
