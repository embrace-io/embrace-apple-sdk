//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//
    
import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceCommonInternal
#endif

class DefaultOTelSignalBridge: EmbraceOTelSignalBridge {

    func startSpan(
        name: String,
        parentSpan: EmbraceSpan?,
        status: EmbraceSpanStatus,
        startTime: Date,
        endTime: Date?,
        events: [EmbraceSpanEvent],
        links: [EmbraceSpanLink],
        attributes: [String : String]
    ) -> EmbraceSpanContext {

        // get trace id from parent if possible
        let traceId = parentSpan?.context.traceId ?? randomTraceId()

        return EmbraceSpanContext(
            spanId: randomSpanId(),
            traceId: traceId
        )
    }
    
    // MARK: No-op
    func updateSpanStatus(_ span: any EmbraceSpan, status: EmbraceSpanStatus) {

    }
    
    func updateSpanAttribute(_ span: any EmbraceSpan, key: String, value: String?) {

    }
    
    func addSpanEvent(_ span: any EmbraceSpan, event: EmbraceSpanEvent) {

    }
    
    func addSpanLink(_ span: any EmbraceSpan, event: EmbraceSpanLink) {

    }
    
    func endSpan(_ span: any EmbraceSpan, endTime: Date) {

    }

    func createLog(_ log: any EmbraceLog) {

    }

    // MARK: Random identifiers
    func randomSpanId() -> String {
        var id: UInt64 = 0
        repeat {
          id = UInt64.random(in: .min ... .max)
        } while id == 0

        return String(format: "%016llx", id)
    }

    func randomTraceId() -> String {
        var idHi: UInt64
        var idLo: UInt64
        repeat {
          idHi = UInt64.random(in: .min ... .max)
          idLo = UInt64.random(in: .min ... .max)
        } while idHi == 0 && idLo == 0

        return String(format: "%016llx%016llx", idHi, idLo)
    }
}
