//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

protocol OTelSignalsLimiter {
    func reset()

    func shouldCreateCustomSpan() -> Bool
    func shouldAddSessionEvent(ofType type: EmbraceType?) -> Bool
    func shouldCreateLog(type: EmbraceType, severity: EmbraceLogSeverity) -> Bool

    func shouldAddSpanEvent(currentCount count: Int) -> Bool
    func shouldAddSpanLink(currentCount count: Int) -> Bool
    func shouldAddSpanAttribute(currentCount count: Int) -> Bool
}
