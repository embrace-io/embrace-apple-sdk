//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceObjCUtils

@objc public class DeviceInfoCollector: NSObject, Collector {

    public func start() {
        let isJailbroken = EMBDevice.isJailbroken
        let locale = EMBDevice.locale
        let timezoneDescription = EMBDevice.timezoneDescription
        let totalDiskSpace = EMBDevice.totalDiskSpace
        let operatingSystemVersion = EMBDevice.operatingSystemVersion
        let operatingSystemBuild = EMBDevice.operatingSystemBuild

        do {
            try Embrace.client?.addResource(key: "device.isJailbroken", value: String(isJailbroken))
            try Embrace.client?.addResource(key: "device.locale", value: locale)
            try Embrace.client?.addResource(key: "device.timezoneDescription", value: timezoneDescription)
            try Embrace.client?.addResource(key: "device.totalDiskSpace", value: totalDiskSpace.intValue)
            try Embrace.client?.addResource(key: "device.operatingSystemVersion", value: operatingSystemVersion)
            try Embrace.client?.addResource(key: "device.operatingSystemBuild", value: operatingSystemBuild)

        } catch let e {
            print("Failed to collect device info metadata \(e.localizedDescription)")
        }
    }

    public func stop() {}

    public func isAvailable() -> Bool {
        return true
    }

}
