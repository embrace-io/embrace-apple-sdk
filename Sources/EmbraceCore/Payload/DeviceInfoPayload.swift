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

    enum CodingKeys: String, CodingKey {
        case isJailbroken = "jb"
        case locale = "lc"
        case timeZone = "tz"
        case totalDiskSpace = "ms"
        case osVersion = "ov"
        case osBuild = "ob"
    }

    init (with resources: [ResourceRecord]) {
        resources.forEach { resource in
            guard let key: DeviceResourceKeys = DeviceResourceKeys(rawValue: resource.key) else {
                return
            }

            let value = resource.value

            switch key {
            case .isJailbroken:
                self.isJailbroken = resource.boolValue
            case .locale:
                self.locale = resource.stringValue
            case .timezone:
                self.timeZone = resource.stringValue
            case .totalDiskSpace:
                self.totalDiskSpace = resource.integerValue
            case .OSVersion:
                self.osVersion = resource.stringValue
            case .OSBuild:
                self.osBuild = resource.stringValue
            }
        }
    }
}
