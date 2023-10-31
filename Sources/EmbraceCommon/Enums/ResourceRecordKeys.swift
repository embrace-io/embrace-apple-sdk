//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public enum AppResourceKeys: String, Codable {
    case buildUUID = "app.build_uuid"
    case bundleVersion = "app.bundle_version"
    case environment = "app.environment"
    case detailedEnvironment = "app.environment_detailed"
    case framework = "app.framework"
    case launchCount = "app.launch_count"
    case sdkVersion = "app.sdk_version"
    case appVersion = "app.version"
}

public enum DeviceResourceKeys: String, Codable {
    case isJailbroken = "device.is_jailbroken"
    case locale = "device.locale"
    case timezone = "device.timezone"
    case totalDiskSpace = "device.disk_size"
    case OSVersion = "os.version"
    case OSBuild = "os.build_id"
}
