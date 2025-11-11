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

    mutating func setEmbraceSessionId(_ sessionId: EmbraceIdentifier?) {
        self[SpanSemantics.keySessionId] = sessionId?.stringValue
    }
}
