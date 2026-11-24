//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

class MockOTelSignalsSanitizer: OTelSignalsSanitizer {

    var sanitizeSpanNameSource: EmbraceOTelSignalSource?
    var sanitizeSpanNameCallCount: Int = 0
    var sanitizeSpanNameReturnValue: String?
    func sanitizeSpanName(_ name: String, source: EmbraceOTelSignalSource) -> String {
        sanitizeSpanNameCallCount += 1
        sanitizeSpanNameSource = source
        return sanitizeSpanNameReturnValue ?? name
    }

    var sanitizeSpanEventNameSource: EmbraceOTelSignalSource?
    var sanitizeSpanEventNameCallCount: Int = 0
    var sanitizeSpanEventNameReturnValue: String?
    func sanitizeSpanEventName(_ name: String, source: EmbraceOTelSignalSource) -> String {
        sanitizeSpanEventNameCallCount += 1
        sanitizeSpanEventNameSource = source
        return sanitizeSpanEventNameReturnValue ?? name
    }

    var sanitizeAttributeKeySource: EmbraceOTelSignalSource?
    var sanitizeAttributeKeyCallCount: Int = 0
    var sanitizeAttributeKeyReturnValue: String?
    func sanitizeAttributeKey(_ key: String, source: EmbraceOTelSignalSource) -> String {
        sanitizeAttributeKeyCallCount += 1
        sanitizeAttributeKeySource = source
        return sanitizeAttributeKeyReturnValue ?? key
    }

    var sanitizeAttributeValueSource: EmbraceOTelSignalSource?
    var sanitizeAttributeValueCallCount: Int = 0
    var sanitizeAttributeValueReturnValue: EmbraceAttributeValue?
    func sanitizeAttributeValue(_ value: EmbraceAttributeValue?, source: EmbraceOTelSignalSource) -> EmbraceAttributeValue? {
        sanitizeAttributeValueCallCount += 1
        sanitizeAttributeValueSource = source
        return sanitizeAttributeValueReturnValue ?? value
    }

    var sanitizeSpanAttributesSource: EmbraceOTelSignalSource?
    var sanitizeSpanAttributesCallCount: Int = 0
    var sanitizeSpanAttributesReturnValue: EmbraceAttributes?
    func sanitizeSpanAttributes(_ attributes: EmbraceAttributes, source: EmbraceOTelSignalSource) -> EmbraceAttributes {
        sanitizeSpanAttributesCallCount += 1
        sanitizeSpanAttributesSource = source
        return sanitizeSpanAttributesReturnValue ?? attributes
    }

    var sanitizeSpanAttributesProtectingSource: EmbraceOTelSignalSource?
    var sanitizeSpanAttributesProtectingCallCount: Int = 0
    var sanitizeSpanAttributesProtectingReturnValue: EmbraceAttributes?
    func sanitizeSpanAttributes(_ attributes: EmbraceAttributes, protecting: Set<String>, source: EmbraceOTelSignalSource) -> EmbraceAttributes {
        sanitizeSpanAttributesProtectingCallCount += 1
        sanitizeSpanAttributesProtectingSource = source
        return sanitizeSpanAttributesProtectingReturnValue ?? attributes
    }

    var sanitizeSpanEventAttributesSource: EmbraceOTelSignalSource?
    var sanitizeSpanEventAttributesCallCount: Int = 0
    var sanitizeSpanEventAttributesReturnValue: EmbraceAttributes?
    func sanitizeSpanEventAttributes(_ attributes: EmbraceAttributes, source: EmbraceOTelSignalSource) -> EmbraceAttributes {
        sanitizeSpanEventAttributesCallCount += 1
        sanitizeSpanEventAttributesSource = source
        return sanitizeSpanEventAttributesReturnValue ?? attributes
    }

    var sanitizeSpanEventAttributesProtectingSource: EmbraceOTelSignalSource?
    var sanitizeSpanEventAttributesProtectingCallCount: Int = 0
    var sanitizeSpanEventAttributesProtectingReturnValue: EmbraceAttributes?
    func sanitizeSpanEventAttributes(_ attributes: EmbraceAttributes, protecting: Set<String>, source: EmbraceOTelSignalSource) -> EmbraceAttributes {
        sanitizeSpanEventAttributesProtectingCallCount += 1
        sanitizeSpanEventAttributesProtectingSource = source
        return sanitizeSpanEventAttributesProtectingReturnValue ?? attributes
    }

    var sanitizeSpanLinkAttributesSource: EmbraceOTelSignalSource?
    var sanitizeSpanLinkAttributesCallCount: Int = 0
    var sanitizeSpanLinkAttributesReturnValue: EmbraceAttributes?
    func sanitizeSpanLinkAttributes(_ attributes: EmbraceAttributes, source: EmbraceOTelSignalSource) -> EmbraceAttributes {
        sanitizeSpanLinkAttributesCallCount += 1
        sanitizeSpanLinkAttributesSource = source
        return sanitizeSpanLinkAttributesReturnValue ?? attributes
    }

    var sanitizeLogAttributesSource: EmbraceOTelSignalSource?
    var sanitizeLogAttributesCallCount: Int = 0
    var sanitizeLogAttributesReturnValue: EmbraceAttributes?
    func sanitizeLogAttributes(_ attributes: EmbraceAttributes, source: EmbraceOTelSignalSource) -> EmbraceAttributes {
        sanitizeLogAttributesCallCount += 1
        sanitizeLogAttributesSource = source
        return sanitizeLogAttributesReturnValue ?? attributes
    }

    var sanitizeLogAttributesProtectingSource: EmbraceOTelSignalSource?
    var sanitizeLogAttributesProtectingCallCount: Int = 0
    var sanitizeLogAttributesProtectingReturnValue: EmbraceAttributes?
    func sanitizeLogAttributes(_ attributes: EmbraceAttributes, protecting: Set<String>, source: EmbraceOTelSignalSource) -> EmbraceAttributes {
        sanitizeLogAttributesProtectingCallCount += 1
        sanitizeLogAttributesProtectingSource = source
        return sanitizeLogAttributesProtectingReturnValue ?? attributes
    }
}
