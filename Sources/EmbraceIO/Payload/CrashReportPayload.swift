//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

struct CrashPayload: Encodable {
    var id: String
    var json: [String: Any]

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case json = "ks"
    }

    init(from: CrashReport) {
        id = from.id.uuidString
        json = from.dictionary
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(json, forKey: .json)
    }
}

struct CrashReportPayload: Encodable {
    var appInfo: AppInfoPayload
    var deviceInfo: DeviceInfoPayload
    var userInfo: UserInfoPayload
    var crashPayload: CrashPayload

    enum CodingKeys: String, CodingKey {
        case appInfo = "a"
        case deviceInfo = "d"
        case userInfo = "u"
        case crashPayload = "cr"
    }

    init(from: CrashReport) {
        appInfo = AppInfoPayload()
        deviceInfo = DeviceInfoPayload()
        userInfo = UserInfoPayload()
        crashPayload = CrashPayload(from: from)
    }
}
