//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceCommonInternal
#endif

protocol OTelSignalsSanitizer {
    func sanitizeSpanName(_ name: String, source: EmbraceOTelSignalSource) -> String
    func sanitizeSpanEventName(_ name: String, source: EmbraceOTelSignalSource) -> String

    func sanitizeAttributeKey(_ key: String, source: EmbraceOTelSignalSource) -> String
    func sanitizeAttributeValue(_ value: EmbraceAttributeValue?, source: EmbraceOTelSignalSource) -> EmbraceAttributeValue?

    func sanitizeSpanAttributes(_ attributes: EmbraceAttributes, source: EmbraceOTelSignalSource) -> EmbraceAttributes
    func sanitizeSpanAttributes(_ attributes: EmbraceAttributes, protecting: Set<String>, source: EmbraceOTelSignalSource) -> EmbraceAttributes
    func sanitizeSpanEventAttributes(_ attributes: EmbraceAttributes, source: EmbraceOTelSignalSource) -> EmbraceAttributes
    func sanitizeSpanEventAttributes(_ attributes: EmbraceAttributes, protecting: Set<String>, source: EmbraceOTelSignalSource) -> EmbraceAttributes
    func sanitizeSpanLinkAttributes(_ attributes: EmbraceAttributes, source: EmbraceOTelSignalSource) -> EmbraceAttributes
    func sanitizeLogAttributes(_ attributes: EmbraceAttributes, source: EmbraceOTelSignalSource) -> EmbraceAttributes
    func sanitizeLogAttributes(_ attributes: EmbraceAttributes, protecting: Set<String>, source: EmbraceOTelSignalSource) -> EmbraceAttributes
}
