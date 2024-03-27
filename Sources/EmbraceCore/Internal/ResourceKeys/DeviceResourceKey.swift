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
    case model = "emb.device.model.identifier"
    case manufacturer = "emb.device.manufacturer"
    case screenResolution = "emb.device.screenResolution"
    case osVersion = "emb.os.version"
    case osBuild = "emb.os.build_id"
    case osType = "emb.os.type"
    case osName = "emb.os.name"
    case osVariant = "emb.os.variant"
    // Note: even though the key was created, there's no real value for this at this moment.
    // We might be able to combine other values to create one for this like "osType + [OSBuild]"
    // Docs: https://opentelemetry.io/docs/specs/semconv/resource/os/
    case osDescription = "emb.os.description"
}
