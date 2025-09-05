//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

extension OTelSignalsHandler {
    func addInternalSessionEvent(_ event: EmbraceSpanEvent) throws {
        guard let internalHandler = self as? EmbraceOTelSignalsHandler else {
            return
        }

        guard let span = internalHandler.sessionController?.currentSessionSpan else {
            throw EmbraceOTelError.invalidSession
        }

        span.addSessionEvent(event, isInternal: true)
    }
}
