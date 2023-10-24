//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorage

struct SessionPayload: Codable {
    let messageFormatVersion: Int
    let sessionInfo: SessionInfoPayload
    let appInfo: AppInfoPayload
    let deviceInfo: DeviceInfoPayload
    let userInfo: UserInfoPayload
    let spans: SpansPayload

    enum CodingKeys: String, CodingKey {
        case messageFormatVersion = "v"
        case sessionInfo = "s"
        case appInfo = "a"
        case deviceInfo = "d"
        case userInfo = "u"
        case spans = "spans"
    }

    init(with sessioinRecord: SessionRecord) {
        self.messageFormatVersion = 15
        self.sessionInfo = SessionInfoPayload(from: sessioinRecord)
        self.appInfo = AppInfoPayload()
        self.deviceInfo = DeviceInfoPayload()
        self.userInfo = UserInfoPayload()
        self.spans = SpansPayload()
    }
}
