//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import EmbraceCommonInternal

extension ReadableLogRecord {
    public var embType: LogType? {
        switch attributes[LogSemantics.keyEmbraceType] {
        case let .string(value):
            return LogType(rawValue: value)
        default:
            return nil
        }
    }

    public func isEmbType(_ type: LogType) -> Bool {
        return embType == type
    }
}
