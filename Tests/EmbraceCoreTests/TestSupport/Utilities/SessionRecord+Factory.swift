//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorageInternal
import EmbraceCommonInternal

extension SessionRecord {
    static func with(id: SessionIdentifier, state: SessionState) -> SessionRecord {
        SessionRecord(
            id: id,
            processId: .random,
            state: state,
            traceId: "",
            spanId: "",
            startTime: Date()
        )
    }
}
