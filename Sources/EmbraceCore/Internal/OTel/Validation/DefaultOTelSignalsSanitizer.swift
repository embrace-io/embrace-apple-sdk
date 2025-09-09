//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

class DefaultOtelSignalsSanitizer: OTelSignalsSanitizer {

    let sessionLimits: SessionLimits
    let attributeLimits: AttributeLimits

    init(sessionLimits: SessionLimits = SessionLimits(), attributeLimits: AttributeLimits = AttributeLimits()) {
        self.sessionLimits = sessionLimits
        self.attributeLimits = attributeLimits
    }

    func sanitizeName(_ name: String, lengthLimit: Int) -> String {
        // trim whitespaces
        let trimSet: CharacterSet = .whitespacesAndNewlines.union(.controlCharacters)
        var result = name.trimmingCharacters(in: trimSet)

        // truncate
        if result.count > lengthLimit {
            result = String(result.prefix(lengthLimit))
            Embrace.logger.warning("Name is too long and has to be truncated!: \(name)")
        }

        return result
    }

    func sanitizeSpanName(_ name: String) -> String {
        return sanitizeName(name, lengthLimit: sessionLimits.customSpans.nameLength)
    }

    func sanitizeSpanEventName(_ name: String) -> String {
        return sanitizeName(name, lengthLimit: sessionLimits.events.nameLength)
    }

    func sanitizeAttributeKey(_ key: String) -> String {
        // truncate
        if key.count > attributeLimits.keyLength {
            Embrace.logger.warning("Attribute key is too long and has to be truncated!: \(key)")
            return String(key.prefix(attributeLimits.keyLength))
        }

        return key
    }

    func sanitizeAttributeValue(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        // truncate
        if value.count > attributeLimits.valueLength {
            Embrace.logger.warning("Attribute value is too long and has to be truncated!: \(value)")
            return String(value.prefix(attributeLimits.valueLength))
        }

        return value
    }

    func sanitizeAttributes(_ attributes: [String: String], limit: Int) -> [String: String] {
        var finalAttributes: [String: String] = [:]
        let sortedKeys = attributes.keys.sorted()
        var count = 0

        for key in sortedKeys {
            guard let value = attributes[key] else {
                continue
            }

            let finalKey = sanitizeAttributeKey(key)
            let finalValue = sanitizeAttributeValue(value)
            finalAttributes[finalKey] = finalValue

            count += 1
            if count >= limit {
                break
            }
        }

        return finalAttributes
    }

    func sanitizeSpanAttributes(_ attributes: [String: String]) -> [String: String] {
        return sanitizeAttributes(attributes, limit: sessionLimits.customSpans.attributeCount)
    }

    func sanitizeSpanEventAttributes(_ attributes: [String: String]) -> [String: String] {
        return sanitizeAttributes(attributes, limit: sessionLimits.events.attributeCount)
    }

    func sanitizeSpanLinkAttributes(_ attributes: [String: String]) -> [String: String] {
        return sanitizeAttributes(attributes, limit: sessionLimits.links.attributeCount)
    }

    func sanitizeLogAttributes(_ attributes: [String: String]) -> [String: String] {
        return sanitizeAttributes(attributes, limit: sessionLimits.logs.attributeCount)
    }
}
