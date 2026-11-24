//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceCommonInternal
#endif

protocol OTelSignalsLimiter {
    func reset()

    func shouldCreateCustomSpan(source: EmbraceOTelSignalSource) -> Bool
    func shouldAddSessionEvent(ofType type: EmbraceType?, source: EmbraceOTelSignalSource) -> Bool
    func shouldCreateLog(type: EmbraceType, severity: EmbraceLogSeverity, source: EmbraceOTelSignalSource) -> Bool

    func shouldAddSpanEvent(currentCount count: Int, source: EmbraceOTelSignalSource) -> Bool
    func shouldAddSpanLink(currentCount count: Int, source: EmbraceOTelSignalSource) -> Bool
    func shouldAddSpanAttribute(currentCount count: Int, source: EmbraceOTelSignalSource) -> Bool
}
