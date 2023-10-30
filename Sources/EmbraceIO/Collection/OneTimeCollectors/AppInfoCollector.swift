//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceObjCUtils

@objc public class AppInfoCollector: NSObject, Collector {
    public func start() {
        let buildUUID = EMBDevice.buildUUID
        let bundleVersion = EMBDevice.bundleVersion
        let environment = EMBDevice.environment
        let environmentDetail = EMBDevice.environmentDetail
        let appVersion = EMBDevice.appVersion

        do {
            try Embrace.client?.addResource(key: "App.buildUUID", value: buildUUID ?? "N/A")
            try Embrace.client?.addResource(key: "App.bundleVersion", value: bundleVersion)
            try Embrace.client?.addResource(key: "App.environment", value: environment)
            try Embrace.client?.addResource(key: "App.environmentDetail", value: environmentDetail)
            try Embrace.client?.addResource(key: "App.appVersion", value: appVersion ?? "N/A")

        } catch let e {
            print("Failed to collect app info metadata \(e.localizedDescription)")
        }
    }

    public func stop() {}

    public func isAvailable() -> Bool {
        return true
    }

}
