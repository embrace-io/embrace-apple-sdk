//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

class MockOTelSignalsSanitizer: OTelSignalsSanitizer {

    var sanitizeSpanNameCallCount: Int = 0
    var sanitizeSpanNameReturnValue: String?
    func sanitizeSpanName(_ name: String) -> String {
        sanitizeSpanNameCallCount += 1
        return sanitizeSpanNameReturnValue ?? name
    }

    var sanitizeSpanEventNameCallCount: Int = 0
    var sanitizeSpanEventNameReturnValue: String?
    func sanitizeSpanEventName(_ name: String) -> String {
        sanitizeSpanEventNameCallCount += 1
        return sanitizeSpanEventNameReturnValue ?? name
    }

    var sanitizeAttributeKeyCallCount: Int = 0
    var sanitizeAttributeKeyReturnValue: String?
    func sanitizeAttributeKey(_ key: String) -> String {
        sanitizeAttributeKeyCallCount += 1
        return sanitizeAttributeKeyReturnValue ?? key
    }

    var sanitizeAttributeValueCallCount: Int = 0
    var sanitizeAttributeValueReturnValue: EmbraceAttributeValue?
    func sanitizeAttributeValue(_ value: EmbraceAttributeValue?) -> EmbraceAttributeValue? {
        sanitizeAttributeValueCallCount += 1
        return sanitizeAttributeValueReturnValue ?? value
    }

    var sanitizeSpanAttributesCallCount: Int = 0
    var sanitizeSpanAttributesReturnValue: EmbraceAttributes?
    func sanitizeSpanAttributes(_ attributes: EmbraceAttributes) -> EmbraceAttributes {
        sanitizeSpanAttributesCallCount += 1
        return sanitizeSpanAttributesReturnValue ?? attributes
    }

    var sanitizeSpanAttributesProtectingCallCount: Int = 0
    var sanitizeSpanAttributesProtectingReturnValue: EmbraceAttributes?
    func sanitizeSpanAttributes(_ attributes: EmbraceAttributes, protecting: Set<String>) -> EmbraceAttributes {
        sanitizeSpanAttributesProtectingCallCount += 1
        return sanitizeSpanAttributesProtectingReturnValue ?? attributes
    }

    var sanitizeSpanEventAttributesCallCount: Int = 0
    var sanitizeSpanEventAttributesReturnValue: EmbraceAttributes?
    func sanitizeSpanEventAttributes(_ attributes: EmbraceAttributes) -> EmbraceAttributes {
        sanitizeSpanEventAttributesCallCount += 1
        return sanitizeSpanEventAttributesReturnValue ?? attributes
    }

    var sanitizeSpanLinkAttributesCallCount: Int = 0
    var sanitizeSpanLinkAttributesReturnValue: EmbraceAttributes?
    func sanitizeSpanLinkAttributes(_ attributes: EmbraceAttributes) -> EmbraceAttributes {
        sanitizeSpanLinkAttributesCallCount += 1
        return sanitizeSpanLinkAttributesReturnValue ?? attributes
    }

    var sanitizeLogAttributesCallCount: Int = 0
    var sanitizeLogAttributesReturnValue: EmbraceAttributes?
    func sanitizeLogAttributes(_ attributes: EmbraceAttributes) -> EmbraceAttributes {
        sanitizeLogAttributesCallCount += 1
        return sanitizeLogAttributesReturnValue ?? attributes
    }

    var sanitizeLogAttributesProtectingCallCount: Int = 0
    var sanitizeLogAttributesProtectingReturnValue: EmbraceAttributes?
    func sanitizeLogAttributes(_ attributes: EmbraceAttributes, protecting: Set<String>) -> EmbraceAttributes {
        sanitizeLogAttributesProtectingCallCount += 1
        return sanitizeLogAttributesProtectingReturnValue ?? attributes
    }
}
