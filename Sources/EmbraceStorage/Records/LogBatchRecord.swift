//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

public typealias BatchId = UUID

public struct LogBatch: Codable {
    public enum State: Codable {
        case open
        case closed
        case delivered // or exported?
    }

    public let id: BatchId
    public var logs: [ReadableLogRecord]
    public var creationDate: Date
    public var state: State

    public init() {
        self.id = BatchId()
        self.logs = []
        self.creationDate = Date()
        self.state = .open
    }
}

extension LogBatch: Equatable {
    public static func == (lhs: LogBatch, rhs: LogBatch) -> Bool {
        lhs.id == rhs.id
    }
}
