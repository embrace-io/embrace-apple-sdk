//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceObjCUtils

@objc public class DeviceInfoCollector: NSObject, Collector {
    typealias Keys = DeviceResourceKeys

    public func start() {
        let isJailbroken = EMBDevice.isJailbroken
        let locale = EMBDevice.locale
        let timezoneDescription = EMBDevice.timezoneDescription
        let totalDiskSpace = EMBDevice.totalDiskSpace
        let operatingSystemVersion = EMBDevice.operatingSystemVersion
        let operatingSystemBuild = EMBDevice.operatingSystemBuild

        do {
            try Embrace.client?.addResource(key: Keys.isJailbroken.rawValue, value: String(isJailbroken))
            try Embrace.client?.addResource(key: Keys.locale.rawValue, value: locale)
            try Embrace.client?.addResource(key: Keys.timezone.rawValue, value: timezoneDescription)
            try Embrace.client?.addResource(key: Keys.totalDiskSpace.rawValue, value: totalDiskSpace.intValue)
            try Embrace.client?.addResource(key: Keys.OSVersion.rawValue, value: operatingSystemVersion)
            try Embrace.client?.addResource(key: Keys.OSBuild.rawValue, value: operatingSystemBuild)

        } catch let e {
            ConsoleLog.error("Failed to collect device info metadata \(e.localizedDescription)")
        }
    }

    public func stop() {}

    public func isAvailable() -> Bool {
        return true
    }

}
