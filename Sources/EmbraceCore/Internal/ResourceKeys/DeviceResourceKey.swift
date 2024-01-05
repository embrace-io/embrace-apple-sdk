//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public enum DeviceResourceKey: String, Codable {
    case isJailbroken = "emb.device.is_jailbroken"
    case locale = "emb.device.locale"
    case timezone = "emb.device.timezone"
    case totalDiskSpace = "emb.device.disk_size"
    case OSVersion = "emb.os.version"
    case OSBuild = "emb.os.build_id"
}
