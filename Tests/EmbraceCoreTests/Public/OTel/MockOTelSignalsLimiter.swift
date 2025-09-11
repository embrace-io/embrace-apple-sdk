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

    var sshouldCreateLogCallCount: Int = 0
    var sshouldCreateLogReturnValue: Bool = true
    func shouldCreateLog(type: EmbraceType, severity: EmbraceLogSeverity) -> Bool {
        sshouldCreateLogCallCount += 1
        return sshouldCreateLogReturnValue
    }

    var shouldAddSpanEventCallCount: Int = 0
    var shouldAddSpanEventReturnValue: Bool = true
    func shouldAddSpanEvent(currentCount count: Int) -> Bool {
        shouldAddSpanEventCallCount += 1
        return shouldAddSpanEventReturnValue
    }

    var shouldAddSpanLinkCallCount: Int = 0
    var shouldAddSpanLinkReturnValue: Bool = true
    func shouldAddSpanLink(currentCount count: Int) -> Bool {
        shouldAddSpanLinkCallCount += 1
        return shouldAddSpanLinkReturnValue
    }

    var shouldAddSpanAttributeCallCount: Int = 0
    var shouldAddSpanAttributeReturnValue: Bool = true
    func shouldAddSpanAttribute(currentCount count: Int) -> Bool {
        shouldAddSpanAttributeCallCount += 1
        return shouldAddSpanAttributeReturnValue
    }

}
