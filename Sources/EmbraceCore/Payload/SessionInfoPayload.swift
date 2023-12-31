//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorage
import EmbraceCommon

struct SessionInfoPayload: Codable {
    let sessionId: SessionIdentifier
    let startTime: Int
    let endTime: Int?
    let lastHeartbeatTime: Int
    let appState: String
    let counter: Int

    enum CodingKeys: String, CodingKey {
        case sessionId = "id"
        case startTime = "st"
        case endTime = "et"
        case lastHeartbeatTime = "ht"
        case appState = "as"
        case counter = "sn"
    }

    init(from sessionRecord: SessionRecord, counter: Int) {
        self.sessionId = sessionRecord.id
        self.startTime = sessionRecord.startTime.millisecondsSince1970Truncated
        self.endTime = sessionRecord.endTime?.millisecondsSince1970Truncated
        self.lastHeartbeatTime = sessionRecord.lastHeartbeatTime.millisecondsSince1970Truncated
        self.appState = sessionRecord.state
        self.counter = counter
    }
}
