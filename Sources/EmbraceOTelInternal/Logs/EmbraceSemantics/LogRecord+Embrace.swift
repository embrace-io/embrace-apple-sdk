//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceCommonInternal
#endif

extension ReadableLogRecord {
    public var embType: LogType? {
        switch attributes[LogSemantics.keyEmbraceType] {
        case .string(let value):
            return LogType(rawValue: value)
        default:
            return nil
        }
    }

    public func isEmbType(_ type: LogType) -> Bool {
        return embType == type
    }
}
