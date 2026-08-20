//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

class MockOTelSignalsLimiter: OTelSignalsLimiter {
    func reset() {

    }

    var shouldCreateCustomSpanCallCount: Int = 0
    var shouldCreateCustomSpanReturnValue: Bool = true
    func shouldCreateCustomSpan() -> Bool {
        shouldCreateCustomSpanCallCount += 1
        return shouldCreateCustomSpanReturnValue
    }

    var shouldAddSessionEventCallCount: Int = 0
    var shouldAddSessionEventReturnValue: Bool = true
    func shouldAddSessionEvent(ofType type: EmbraceType?) -> Bool {
        shouldAddSessionEventCallCount += 1
        return shouldAddSessionEventReturnValue
    }

    var shouldCreateLogCallCount: Int = 0
    var shouldCreateLogReturnValue: Bool = true
    func shouldCreateLog(type: EmbraceType, severity: EmbraceLogSeverity) -> Bool {
        shouldCreateLogCallCount += 1
        return shouldCreateLogReturnValue
    }

    var shouldAddSpanEventCallCount: Int = 0
    var shouldAddSpanEventReturnValue: Bool = true
    var shouldAddSpanEventStub: ((Int) -> Bool)?
    func shouldAddSpanEvent(currentCount count: Int) -> Bool {
        shouldAddSpanEventCallCount += 1
        if let shouldAddSpanEventStub {
            return shouldAddSpanEventStub(count)
        }
        return shouldAddSpanEventReturnValue
    }

    var shouldAddSpanLinkCallCount: Int = 0
    var shouldAddSpanLinkReturnValue: Bool = true
    var shouldAddSpanLinkStub: ((Int) -> Bool)?
    func shouldAddSpanLink(currentCount count: Int) -> Bool {
        shouldAddSpanLinkCallCount += 1
        if let shouldAddSpanLinkStub {
            return shouldAddSpanLinkStub(count)
        }
        return shouldAddSpanLinkReturnValue
    }

    var shouldAddSpanAttributeCallCount: Int = 0
    var shouldAddSpanAttributeReturnValue: Bool = true
    func shouldAddSpanAttribute(currentCount count: Int) -> Bool {
        shouldAddSpanAttributeCallCount += 1
        return shouldAddSpanAttributeReturnValue
    }

}
