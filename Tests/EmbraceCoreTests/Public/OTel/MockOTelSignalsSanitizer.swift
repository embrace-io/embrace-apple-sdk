//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

class MockOTelSignalsSanitizier: OTelSignalsSanitizer {

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
    var sanitizeAttributeValueReturnValue: String?
    func sanitizeAttributeValue(_ value: String?) -> String? {
        sanitizeAttributeValueCallCount += 1
        return sanitizeAttributeValueReturnValue ?? value
    }

    var sanitizeSpanAttributesCallCount: Int = 0
    var sanitizeSpanAttributesReturnValue: [String: String]?
    func sanitizeSpanAttributes(_ attributes: [String: String]) -> [String: String] {
        sanitizeSpanAttributesCallCount += 1
        return sanitizeSpanAttributesReturnValue ?? attributes
    }

    var sanitizeSpanEventAttributesCallCount: Int = 0
    var sanitizeSpanEventAttributesReturnValue: [String: String]?
    func sanitizeSpanEventAttributes(_ attributes: [String: String]) -> [String: String] {
        sanitizeSpanEventAttributesCallCount += 1
        return sanitizeSpanEventAttributesReturnValue ?? attributes
    }

    var sanitizeSpanLinkAttributesCallCount: Int = 0
    var sanitizeSpanLinkAttributesReturnValue: [String: String]?
    func sanitizeSpanLinkAttributes(_ attributes: [String: String]) -> [String: String] {
        sanitizeSpanLinkAttributesCallCount += 1
        return sanitizeSpanLinkAttributesReturnValue ?? attributes
    }

    var sanitizeLogAttributesCallCount: Int = 0
    var sanitizeLogAttributesReturnValue: [String: String]?
    func sanitizeLogAttributes(_ attributes: [String: String]) -> [String: String] {
        sanitizeLogAttributesCallCount += 1
        return sanitizeLogAttributesReturnValue ?? attributes
    }
}
