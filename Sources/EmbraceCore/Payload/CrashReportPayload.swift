//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceStorage

struct CrashPayload: Encodable {
    var id: String
    var json: [String: Any]

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case json = "ks"
    }

    init(from crashReport: CrashReport) {
        id = crashReport.id.uuidString
        json = crashReport.dictionary
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

    init(from crashReport: CrashReport, resourceFetcher: EmbraceStorageResourceFetcher) {
        let resources = PayloadUtils.fetchResources(from: resourceFetcher, sessionId: crashReport.sessionId)

        appInfo = AppInfoPayload(with: resources)
        deviceInfo = DeviceInfoPayload(with: resources)
        userInfo = UserInfoPayload(with: resources)
        crashPayload = CrashPayload(from: crashReport)
    }
}
