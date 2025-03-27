//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public protocol EmbraceSpan {
    var id: String { get }
    var name: String { get }
    var traceId: String { get }
    var typeRaw: String { get }
    var data: Data { get }
    var startTime: Date { get }
    var endTime: Date? { get }
    var processIdRaw: String { get }
}

public extension EmbraceSpan {
    var type: SpanType? {
        return SpanType(rawValue: typeRaw)
    }

    var processId: ProcessIdentifier? {
        return ProcessIdentifier(hex: processIdRaw)
    }
}
