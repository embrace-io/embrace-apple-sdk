//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(WebKit)
    import Foundation

    /// Rewrites the URLs captured from a web view according to the privacy settings in `WebViewCaptureService.Options`.
    ///
    /// All the processing happens on the raw URL string, exactly as it was captured and still percent-encoded.
    /// Percent-decoding before parsing would turn an encoded separator such as `%26` into a live one, so nothing
    /// here decodes anything: the parts of the URL that are kept are emitted byte for byte.
    ///
    /// The scanning is done over UTF-8 bytes rather than characters. Every delimiter this looks for is ASCII, and
    /// walking a string by `Character` means segmenting it into grapheme clusters, which costs several times more
    /// than the rest of the work put together.
    enum WebViewURLSanitizer {

        /// The longest text that can plausibly be a parameter name in a fragment segment.
        static let maxKeyLength = 64

        /// The length at which a fragment segment with no recognizable structure stops being a label, such as an
        /// anchor, and starts being a payload, such as base64 application state or a token.
        static let opaqueSegmentThreshold = 64

        /// The maximum number of times redaction recurses into the query of a hash route.
        static let maxRecursionDepth = 4

        private static let hash = UInt8(ascii: "#")
        private static let questionMark = UInt8(ascii: "?")
        private static let equals = UInt8(ascii: "=")
        private static let slash = UInt8(ascii: "/")
        private static let exclamationMark = UInt8(ascii: "!")

        /// The bytes that act as separators between the segments of a fragment. Both turn up in real data.
        private static let separators: Set<UInt8> = [UInt8(ascii: "&"), UInt8(ascii: ";")]

        /// The bytes that a parameter name can never contain: the URL delimiters, and whitespace.
        ///
        /// This is a denylist rather than an allowlist such as `[A-Za-z0-9_-]` on purpose: real parameter names
        /// include shapes like `mids[]` and `filter:name`, and rejecting those would keep their values.
        private static let invalidKeyBytes: Set<UInt8> = [
            UInt8(ascii: "/"), UInt8(ascii: "?"), UInt8(ascii: "#"), UInt8(ascii: "&"), UInt8(ascii: "="),
            0x20, 0x09, 0x0A, 0x0B, 0x0C, 0x0D
        ]

        /// Returns the given URL string with the query and the fragment processed as requested.
        /// - Parameters:
        ///   - urlString: The URL exactly as it was captured.
        ///   - stripQueryParams: Whether the query component should be removed.
        ///   - fragmentHandling: How the fragment component should be treated.
        static func sanitize(
            _ urlString: String,
            stripQueryParams: Bool,
            fragmentHandling: WebViewCaptureService.FragmentHandling
        ) -> String {

            guard stripQueryParams || fragmentHandling != .keep else {
                return urlString
            }

            let bytes = urlString.utf8

            // The fragment is the last component of a URL and runs to its end, and a literal `#` inside a fragment
            // must be percent-encoded, so the first `#` is always the delimiter and any later one is data.
            var base = bytes[bytes.startIndex..<bytes.endIndex]
            var fragment: Substring.UTF8View?

            if let hashIndex = bytes.firstIndex(of: hash) {
                base = bytes[bytes.startIndex..<hashIndex]
                fragment = bytes[bytes.index(after: hashIndex)..<bytes.endIndex]
            }

            // With the fragment already separated, the query runs from the first `?` to the end of the base. This
            // is what keeps the two settings independent of each other.
            if stripQueryParams, let queryIndex = base.firstIndex(of: questionMark) {
                base = base[base.startIndex..<queryIndex]
            }

            guard let fragment = fragment else {
                return string(base)
            }

            switch fragmentHandling {
            case .keep:
                return string(base) + "#" + string(fragment)
            case .remove:
                return string(base)
            case .redact:
                return string(base) + "#" + redact(fragment, depth: 0)
            }
        }

        /// Redacts a fragment, or the query of a hash route inside one, by splitting it into segments and taking
        /// each through the segment rules. The separators and their positions are preserved, so a segment that is
        /// dropped leaves an empty segment behind and the shape of the fragment survives.
        private static func redact(_ text: Substring.UTF8View, depth: Int) -> String {
            var result = ""
            result.reserveCapacity(text.count)

            var segmentStart = text.startIndex
            var index = text.startIndex

            while index < text.endIndex {
                let byte = text[index]

                if separators.contains(byte) {
                    result += redactSegment(text[segmentStart..<index], depth: depth)
                    result.append(Character(UnicodeScalar(byte)))
                    segmentStart = text.index(after: index)
                }

                index = text.index(after: index)
            }

            result += redactSegment(text[segmentStart..<text.endIndex], depth: depth)

            return result
        }

        /// Applies the segment rules, first match wins.
        private static func redactSegment(_ segment: Substring.UTF8View, depth: Int) -> String {

            // A `key=value` pair whose name is plausibly a parameter name: keep the name and the `=`, drop the
            // value. The name is validated instead of simply splitting on the first `=`, because an opaque payload
            // can contain an `=` too: the base64 padding at the end of a long blob would otherwise be read as one
            // enormous name with an empty value, and the whole blob would be preserved.
            if let equalsIndex = segment.firstIndex(of: equals),
                isPlausibleKey(segment[segment.startIndex..<equalsIndex])
            {
                return string(segment[segment.startIndex...equalsIndex])
            }

            // A hash route, which carries the screen the user was on rather than sensitive data: keep it, and take
            // anything after a `?` within it through the same rules. Excluding `/` and `?` from parameter names
            // above is what lets a route like `/search?q=shoes` reach this rule.
            if let first = segment.first, first == slash || first == exclamationMark {
                guard let queryIndex = segment.firstIndex(of: questionMark) else {
                    return string(segment)
                }

                let route = segment[segment.startIndex...queryIndex]

                // Past the nesting limit the route is kept but its query is dropped rather than emitted as-is.
                // Text this deep in a fragment has stopped being something we can claim to have parsed, and
                // keeping it would keep whatever values it holds.
                guard depth < maxRecursionDepth else {
                    return string(route)
                }

                let query = segment[segment.index(after: queryIndex)..<segment.endIndex]

                return string(route) + redact(query, depth: depth + 1)
            }

            // No recognizable structure: short enough to be a label, or long enough to be a payload.
            return segment.count <= opaqueSegmentThreshold ? string(segment) : ""
        }

        /// Returns whether the given text could plausibly be the name of a parameter.
        private static func isPlausibleKey(_ key: Substring.UTF8View) -> Bool {
            guard !key.isEmpty, key.count <= maxKeyLength else {
                return false
            }

            return !key.contains { invalidKeyBytes.contains($0) }
        }

        private static func string(_ bytes: Substring.UTF8View) -> String {
            String(decoding: bytes, as: UTF8.self)
        }
    }
#endif
