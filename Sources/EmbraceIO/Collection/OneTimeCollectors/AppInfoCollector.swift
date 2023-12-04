//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceObjCUtils

@objc public class AppInfoCollector: NSObject, Collector {
    typealias Keys = AppResourceKeys

    let resourceHandler: CollectedResourceHandlerType

    init(resourceHandler: CollectedResourceHandlerType = CollectedResourceHandler()) {
        self.resourceHandler = resourceHandler
    }

    public func start() {
        let buildUUID = EMBDevice.buildUUID
        let bundleVersion = EMBDevice.bundleVersion
        let environment = EMBDevice.environment
        let environmentDetail = EMBDevice.environmentDetail
        let appVersion = EMBDevice.appVersion
        let bundleId = Bundle.main.bundleIdentifier

        do {
            try resourceHandler.addResource(key: Keys.buildUUID.rawValue, value: buildUUID ?? "N/A")
            try resourceHandler.addResource(key: Keys.bundleVersion.rawValue, value: bundleVersion)
            try resourceHandler.addResource(key: Keys.environment.rawValue, value: environment)
            try resourceHandler.addResource(key: Keys.detailedEnvironment.rawValue, value: environmentDetail)
            try resourceHandler.addResource(key: Keys.appVersion.rawValue, value: appVersion ?? "N/A")
            try resourceHandler.addResource(key: Keys.bundleId.rawValue, value: bundleId ?? "N/A")
        } catch let e {
            ConsoleLog.error("Failed to collect app info metadata \(e.localizedDescription)")
        }
    }

    public func stop() {}
}
