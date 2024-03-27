//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceStorage

struct DeviceInfoPayload: Codable {
    var isJailbroken: Bool?
    var locale: String?
    var timeZone: String?
    var totalDiskSpace: Int?
    var osVersion: String?
    var osBuild: String?
    var osType: String? = "iOS"
    var osVariant: String?
    var architecture: String?
    var model: String?
    var manufacturer: String? = "Apple"
    var screenResolution: String?

    enum CodingKeys: String, CodingKey {
        case isJailbroken = "jb"
        case locale = "lc"
        case timeZone = "tz"
        case totalDiskSpace = "ms"
        case osVersion = "ov"
        case osBuild = "ob"
        case osType = "os"
        case osVariant = "oa"
        case architecture = "da"
        case model = "do"
        case manufacturer = "dm"
        case screenResolution = "sr"
    }

    init(with resources: [MetadataRecord]) {
        resources.forEach { resource in
            guard let key: DeviceResourceKey = DeviceResourceKey(rawValue: resource.key) else {
                return
            }

            switch key {
            case .isJailbroken:
                self.isJailbroken = resource.boolValue
            case .locale:
                self.locale = resource.stringValue
            case .timezone:
                self.timeZone = resource.stringValue
            case .totalDiskSpace:
                self.totalDiskSpace = resource.integerValue
            case .osVersion:
                self.osVersion = resource.stringValue
            case .osBuild:
                self.osBuild = resource.stringValue
            case .architecture:
                self.architecture = resource.stringValue
            case .model:
                self.model = resource.stringValue
            case .manufacturer:
                self.manufacturer = resource.stringValue
            case .screenResolution:
                self.screenResolution = resource.stringValue
            case .osType:
                self.osType = resource.stringValue
            case .osVariant:
                self.osVariant = resource.stringValue
            case .osName, .osDescription:
                break
            }
        }
    }
}
