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
    func sanitizeAttributeValue(_ value: String?) -> String?

    func sanitizeSpanAttributes(_ attributes: [String: String]) -> [String: String]
    func sanitizeSpanEventAttributes(_ attributes: [String: String]) -> [String: String]
    func sanitizeSpanLinkAttributes(_ attributes: [String: String]) -> [String: String]
    func sanitizeLogAttributes(_ attributes: [String: String]) -> [String: String]
}
