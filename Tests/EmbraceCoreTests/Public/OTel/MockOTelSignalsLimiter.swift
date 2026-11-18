//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

class MockOTelSignalsLimiter: OTelSignalsLimiter {
    func reset() {

    }

    var shouldCreateCustomSpanSource: EmbraceOTelSignalSource?
    var shouldCreateCustomSpanCallCount: Int = 0
    var shouldCreateCustomSpanReturnValue: Bool = true
    func shouldCreateCustomSpan(source: EmbraceOTelSignalSource) -> Bool {
        shouldCreateCustomSpanCallCount += 1
        shouldCreateCustomSpanSource = source
        return shouldCreateCustomSpanReturnValue
    }

    var shouldAddSessionEventSource: EmbraceOTelSignalSource?
    var shouldAddSessionEventCallCount: Int = 0
    var shouldAddSessionEventReturnValue: Bool = true
    func shouldAddSessionEvent(ofType type: EmbraceType?, source: EmbraceOTelSignalSource) -> Bool {
        shouldAddSessionEventCallCount += 1
        shouldAddSessionEventSource = source
        return shouldAddSessionEventReturnValue
    }

    var shouldCreateLogSource: EmbraceOTelSignalSource?
    var shouldCreateLogCallCount: Int = 0
    var shouldCreateLogReturnValue: Bool = true
    func shouldCreateLog(type: EmbraceType, severity: EmbraceLogSeverity, source: EmbraceOTelSignalSource) -> Bool {
        shouldCreateLogCallCount += 1
        shouldCreateLogSource = source
        return shouldCreateLogReturnValue
    }

    var shouldAddSpanEventSource: EmbraceOTelSignalSource?
    var shouldAddSpanEventCallCount: Int = 0
    var shouldAddSpanEventReturnValue: Bool = true
    var shouldAddSpanEventStub: ((Int) -> Bool)?
    func shouldAddSpanEvent(currentCount count: Int, source: EmbraceOTelSignalSource) -> Bool {
        shouldAddSpanEventCallCount += 1
        shouldAddSpanEventSource = source
        if let shouldAddSpanEventStub {
            return shouldAddSpanEventStub(count)
        }
        return shouldAddSpanEventReturnValue
    }

    var shouldAddSpanLinkSource: EmbraceOTelSignalSource?
    var shouldAddSpanLinkCallCount: Int = 0
    var shouldAddSpanLinkReturnValue: Bool = true
    var shouldAddSpanLinkStub: ((Int) -> Bool)?
    func shouldAddSpanLink(currentCount count: Int, source: EmbraceOTelSignalSource) -> Bool {
        shouldAddSpanLinkCallCount += 1
        shouldAddSpanLinkSource = source
        if let shouldAddSpanLinkStub {
            return shouldAddSpanLinkStub(count)
        }
        return shouldAddSpanLinkReturnValue
    }

    var shouldAddSpanAttributeSource: EmbraceOTelSignalSource?
    var shouldAddSpanAttributeCallCount: Int = 0
    var shouldAddSpanAttributeReturnValue: Bool = true
    func shouldAddSpanAttribute(currentCount count: Int, source: EmbraceOTelSignalSource) -> Bool {
        shouldAddSpanAttributeCallCount += 1
        shouldAddSpanAttributeSource = source
        return shouldAddSpanAttributeReturnValue
    }

}
