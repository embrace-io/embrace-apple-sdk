//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceObjCUtils

@objc public class AppInfoCollector: NSObject, Collector {
    typealias Keys = AppResourceKeys

    public func start() {
        let buildUUID = EMBDevice.buildUUID
        let bundleVersion = EMBDevice.bundleVersion
        let environment = EMBDevice.environment
        let environmentDetail = EMBDevice.environmentDetail
        let appVersion = EMBDevice.appVersion

        do {
            try Embrace.client?.addResource(key: Keys.buildUUID.rawValue, value: buildUUID ?? "N/A")
            try Embrace.client?.addResource(key: Keys.bundleVersion.rawValue, value: bundleVersion)
            try Embrace.client?.addResource(key: Keys.environment.rawValue, value: environment)
            try Embrace.client?.addResource(key: Keys.detailedEnvironment.rawValue, value: environmentDetail)
            try Embrace.client?.addResource(key: Keys.appVersion.rawValue, value: appVersion ?? "N/A")

        } catch let e {
            ConsoleLog.error("Failed to collect app info metadata \(e.localizedDescription)")
        }
    }

    public func stop() {}

    public func isAvailable() -> Bool {
        return true
    }

}
