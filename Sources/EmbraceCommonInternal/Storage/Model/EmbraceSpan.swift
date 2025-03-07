//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public protocol EmbraceSpan {
    var id: String { get set }
    var name: String { get set }
    var traceId: String { get set }
    var typeRaw: String { get set }
    var data: Data { get set }
    var startTime: Date { get set }
    var endTime: Date? { get set }
    var processIdRaw: String { get set }
}

public extension EmbraceSpan {
    var type: SpanType? {
        return SpanType(rawValue: typeRaw)
    }

    var processId: ProcessIdentifier? {
        return ProcessIdentifier(hex: processIdRaw)
    }
}
