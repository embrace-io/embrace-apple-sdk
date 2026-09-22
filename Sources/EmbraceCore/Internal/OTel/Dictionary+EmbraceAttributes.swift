//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

extension Dictionary where Key == String, Value == EmbraceAttributeValue {
    mutating func setEmbraceType(_ type: EmbraceType) {
        self[SpanSemantics.keyEmbraceType] = type.rawValue
    }

    /// Stamps the three identity keys that must appear on every span and every log:
    /// `session.id` (= user-session UUID), `emb.user_session_id`, and `emb.session_part_id`.
    /// All three are emitted unconditionally — empty strings when unknown — because the
    /// backend uses the presence of `emb.session_part_id` to detect new SDKs.
    mutating func setSessionIdentity(userSessionId: String, partId: String) {
        self[SpanSemantics.keySessionId] = userSessionId
        self[SpanSemantics.Session.keyUserSessionId] = userSessionId
        self[SpanSemantics.Session.keyPartId] = partId
    }
}
