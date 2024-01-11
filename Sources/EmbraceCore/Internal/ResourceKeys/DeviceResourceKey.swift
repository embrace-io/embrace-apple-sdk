//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public enum DeviceResourceKey: String, Codable {
    case isJailbroken = "emb.device.is_jailbroken"
    case locale = "emb.device.locale"
    case timezone = "emb.device.timezone"
    case totalDiskSpace = "emb.device.disk_size"
    case architecture = "emb.device.architecture"
    case model = "emb.device.model"
    case manufacturer = "emb.device.manufacturer"
    case screenResolution = "emb.device.screenResolution"
    case OSVersion = "emb.os.version"
    case OSBuild = "emb.os.build_id"
    case osType = "emb.os.type"
    case osVariant = "emb.os.variant"
}
