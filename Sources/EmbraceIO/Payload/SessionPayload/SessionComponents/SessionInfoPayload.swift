//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorage
import EmbraceCommon

struct SessionInfoPayload: Codable {
    let sessionId: SessionId
    let startTime: Int
    let endTime: Int?
    let appState: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "id"
        case startTime = "st"
        case endTime = "et"
        case appState = "as"
    }

    init(from sessionRecord: SessionRecord) {
        self.sessionId = sessionRecord.id
        self.startTime = sessionRecord.startTime.millisecondsSince1970Truncated
        self.endTime = sessionRecord.endTime?.millisecondsSince1970Truncated
        self.appState = sessionRecord.state
    }
}
