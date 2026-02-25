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

    func sanitizeAttributeValue(_ value: EmbraceAttributeValue?) -> EmbraceAttributeValue? {
        guard let value = value as? String else {
            return value
        }

        // truncate
        if value.count > attributeLimits.valueLength {
            Embrace.logger.warning("Attribute value is too long and has to be truncated!: \(value)")
            return String(value.prefix(attributeLimits.valueLength))
        }

        return value
    }

    func sanitizeAttributes(_ attributes: EmbraceAttributes, limit: Int) -> EmbraceAttributes {
        var finalAttributes: EmbraceAttributes = [:]
        let sortedKeys = attributes.keys.sorted()
        var count = 0

        for key in sortedKeys {
            guard let value = attributes[key] as? String else {
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

    func sanitizeSpanAttributes(_ attributes: EmbraceAttributes) -> EmbraceAttributes {
        return sanitizeSpanAttributes(attributes, protecting: [])
    }

    func sanitizeSpanAttributes(_ attributes: EmbraceAttributes, protecting protectedKeys: Set<String>) -> EmbraceAttributes {
        // Always include protected entries — they bypass truncation and count limits.
        let protectedEntries = attributes.filter { protectedKeys.contains($0.key) }
        let unprotected = attributes.filter { !protectedKeys.contains($0.key) }

        var result = sanitizeAttributes(unprotected, limit: sessionLimits.customSpans.attributeCount)

        // Merge protected entries back on top so they always win.
        for (key, value) in protectedEntries {
            result[key] = value
        }

        return result
    }

    func sanitizeSpanEventAttributes(_ attributes: EmbraceAttributes) -> EmbraceAttributes {
        return sanitizeAttributes(attributes, limit: sessionLimits.events.attributeCount)
    }

    func sanitizeSpanLinkAttributes(_ attributes: EmbraceAttributes) -> EmbraceAttributes {
        return sanitizeAttributes(attributes, limit: sessionLimits.links.attributeCount)
    }

    func sanitizeLogAttributes(_ attributes: EmbraceAttributes) -> EmbraceAttributes {
        return sanitizeLogAttributes(attributes, protecting: [])
    }

    func sanitizeLogAttributes(_ attributes: EmbraceAttributes, protecting protectedKeys: Set<String>) -> EmbraceAttributes {
        let protectedEntries = attributes.filter { protectedKeys.contains($0.key) }
        let unprotected = attributes.filter { !protectedKeys.contains($0.key) }

        var result = sanitizeAttributes(unprotected, limit: sessionLimits.logs.attributeCount)

        for (key, value) in protectedEntries {
            result[key] = value
        }

        return result
    }
}
