//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceCommonInternal
#endif

class DefaultOtelSignalsSanitizer: OTelSignalsSanitizer {

    let sessionLimits: SessionLimits
    let attributeLimits: AttributeLimits

    init(sessionLimits: SessionLimits = SessionLimits(), attributeLimits: AttributeLimits = AttributeLimits()) {
        self.sessionLimits = sessionLimits
        self.attributeLimits = attributeLimits
    }

    func sanitizeName(_ name: String, lengthLimit: Int?) -> String {
        // trim whitespaces
        let trimSet: CharacterSet = .whitespacesAndNewlines.union(.controlCharacters)
        var result = name.trimmingCharacters(in: trimSet)

        // truncate
        if let lengthLimit, result.count > lengthLimit {
            result = String(result.prefix(lengthLimit))
            Embrace.logger.warning("Name is too long and has to be truncated!: \(name)")
        }

        return result
    }

    func sanitizeSpanName(_ name: String, source: EmbraceOTelSignalSource) -> String {
        guard let limits = sessionLimits.limits(for: source) else {
            return name
        }

        return sanitizeName(name, lengthLimit: limits.customSpans.nameLength)
    }

    func sanitizeSpanEventName(_ name: String, source: EmbraceOTelSignalSource) -> String {
        guard let limits = sessionLimits.limits(for: source) else {
            return name
        }

        return sanitizeName(name, lengthLimit: limits.events.nameLength)
    }

    func sanitizeAttributeKey(_ key: String, source: EmbraceOTelSignalSource) -> String {
        return sanitizeAttributeKey(key, limits: attributeLimits.limits(for: source))
    }

    func sanitizeAttributeValue(_ value: EmbraceAttributeValue?, source: EmbraceOTelSignalSource) -> EmbraceAttributeValue? {
        return sanitizeAttributeValue(value, limits: attributeLimits.limits(for: source))
    }

    func sanitizeAttributes(_ attributes: EmbraceAttributes, limit: Int, source: EmbraceOTelSignalSource) -> EmbraceAttributes {
        let lengthLimits = attributeLimits.limits(for: source)

        var finalAttributes: EmbraceAttributes = [:]
        let sortedKeys = attributes.keys.sorted()
        var count = 0

        for key in sortedKeys {
            guard let value = attributes[key] else {
                continue
            }

            let finalKey = sanitizeAttributeKey(key, limits: lengthLimits)
            let finalValue = sanitizeAttributeValue(value, limits: lengthLimits)
            finalAttributes[finalKey] = finalValue

            count += 1
            if count >= limit {
                break
            }
        }

        return finalAttributes
    }

    func sanitizeSpanAttributes(_ attributes: EmbraceAttributes, source: EmbraceOTelSignalSource) -> EmbraceAttributes {
        return sanitizeSpanAttributes(attributes, protecting: [], source: source)
    }

    func sanitizeSpanAttributes(
        _ attributes: EmbraceAttributes,
        protecting protectedKeys: Set<String>,
        source: EmbraceOTelSignalSource
    ) -> EmbraceAttributes {
        guard let limits = sessionLimits.limits(for: source) else {
            return attributes
        }

        return sanitizeAttributes(attributes, protecting: protectedKeys, limit: limits.customSpans.attributeCount, source: source)
    }

    func sanitizeSpanEventAttributes(_ attributes: EmbraceAttributes, source: EmbraceOTelSignalSource) -> EmbraceAttributes {
        return sanitizeSpanEventAttributes(attributes, protecting: [], source: source)
    }

    func sanitizeSpanEventAttributes(
        _ attributes: EmbraceAttributes,
        protecting protectedKeys: Set<String>,
        source: EmbraceOTelSignalSource
    ) -> EmbraceAttributes {
        guard let limits = sessionLimits.limits(for: source) else {
            return attributes
        }

        return sanitizeAttributes(attributes, protecting: protectedKeys, limit: limits.events.attributeCount, source: source)
    }

    func sanitizeSpanLinkAttributes(_ attributes: EmbraceAttributes, source: EmbraceOTelSignalSource) -> EmbraceAttributes {
        guard let limits = sessionLimits.limits(for: source) else {
            return attributes
        }

        return sanitizeAttributes(attributes, limit: limits.links.attributeCount, source: source)
    }

    func sanitizeLogAttributes(_ attributes: EmbraceAttributes, source: EmbraceOTelSignalSource) -> EmbraceAttributes {
        return sanitizeLogAttributes(attributes, protecting: [], source: source)
    }

    func sanitizeLogAttributes(
        _ attributes: EmbraceAttributes,
        protecting protectedKeys: Set<String>,
        source: EmbraceOTelSignalSource
    ) -> EmbraceAttributes {
        guard let limits = sessionLimits.limits(for: source) else {
            return attributes
        }

        return sanitizeAttributes(attributes, protecting: protectedKeys, limit: limits.logs.attributeCount, source: source)
    }

    // MARK: Private

    private func sanitizeAttributeKey(_ key: String, limits: AttributeLengthLimits?) -> String {
        guard let keyLength = limits?.keyLength else {
            return key
        }

        // truncate
        if key.count > keyLength {
            Embrace.logger.warning("Attribute key is too long and has to be truncated!: \(key)")
            return String(key.prefix(keyLength))
        }

        return key
    }

    private func sanitizeAttributeValue(_ value: EmbraceAttributeValue?, limits: AttributeLengthLimits?) -> EmbraceAttributeValue? {
        guard let valueLength = limits?.valueLength,
            let value = value as? String
        else {
            return value
        }

        // truncate
        if value.count > valueLength {
            Embrace.logger.warning("Attribute value is too long and has to be truncated!: \(value)")
            return String(value.prefix(valueLength))
        }

        return value
    }

    /// Protected entries bypass truncation and count limits, and always win over unprotected ones.
    private func sanitizeAttributes(
        _ attributes: EmbraceAttributes,
        protecting protectedKeys: Set<String>,
        limit: Int,
        source: EmbraceOTelSignalSource
    ) -> EmbraceAttributes {
        let protectedEntries = attributes.filter { protectedKeys.contains($0.key) }
        let unprotected = attributes.filter { !protectedKeys.contains($0.key) }

        var result = sanitizeAttributes(unprotected, limit: limit, source: source)

        for (key, value) in protectedEntries {
            result[key] = value
        }

        return result
    }
}
