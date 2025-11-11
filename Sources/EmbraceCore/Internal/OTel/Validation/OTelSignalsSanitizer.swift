//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

protocol OTelSignalsSanitizer {
    func sanitizeSpanName(_ name: String) -> String
    func sanitizeSpanEventName(_ name: String) -> String

    func sanitizeAttributeKey(_ key: String) -> String
    func sanitizeAttributeValue(_ value: EmbraceAttributeValue?) -> EmbraceAttributeValue?

    func sanitizeSpanAttributes(_ attributes: EmbraceAttributes) -> EmbraceAttributes
    func sanitizeSpanEventAttributes(_ attributes: EmbraceAttributes) -> EmbraceAttributes
    func sanitizeSpanLinkAttributes(_ attributes: EmbraceAttributes) -> EmbraceAttributes
    func sanitizeLogAttributes(_ attributes: EmbraceAttributes) -> EmbraceAttributes
}
