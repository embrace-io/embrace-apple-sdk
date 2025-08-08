//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceCommonInternal
#endif

extension ReadableLogRecord {
    public var embType: EmbraceType? {
        switch attributes[LogSemantics.keyEmbraceType] {
        case let .string(value):
            return EmbraceType(rawValue: value)
        default:
            return nil
        }
    }

    public func isEmbType(_ type: EmbraceType) -> Bool {
        return embType == type
    }
}
