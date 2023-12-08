//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorage
import EmbraceOTel

struct SessionPayload: Encodable {
    let messageFormatVersion: Int
    let sessionInfo: SessionInfoPayload
    let appInfo: AppInfoPayload
    let deviceInfo: DeviceInfoPayload
    let userInfo: UserInfoPayload
    let spans: [SpanPayload]
    let spanSnapshots: [SpanPayload]

    enum CodingKeys: String, CodingKey {
        case messageFormatVersion = "v"
        case sessionInfo = "s"
        case appInfo = "a"
        case deviceInfo = "d"
        case userInfo = "u"
        case spans = "spans"
        case spanSnapshots = "span_snapshots"
    }

    init(
        from sessionRecord: SessionRecord,
        resourceFetcher: EmbraceStorageResourceFetcher,
        spans: [SpanPayload] = [],
        spanSnapshots: [SpanPayload] = [],
        counter: Int = -1
    ) {
        let resources = PayloadUtils.fetchResources(from: resourceFetcher, sessionId: sessionRecord.id)

        self.messageFormatVersion = 15
        self.sessionInfo = SessionInfoPayload(from: sessionRecord, counter: counter)
        self.appInfo = AppInfoPayload(with: resources)
        self.deviceInfo = DeviceInfoPayload(with: resources)
        self.userInfo = UserInfoPayload()
        self.spans = spans
        self.spanSnapshots = spanSnapshots
    }
}
