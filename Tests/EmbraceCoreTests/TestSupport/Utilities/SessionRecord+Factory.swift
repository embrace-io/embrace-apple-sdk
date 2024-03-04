//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorage
import EmbraceCommon

extension SessionRecord {
    static func with(id: UUID, state: SessionState) -> SessionRecord {
        .init(
            id: .init(value: id),
            state: state,
            processId: .random,
            traceId: "",
            spanId: "",
            startTime: Date()
        )
    }
}
