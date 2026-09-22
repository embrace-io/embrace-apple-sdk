//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(WebKit)
    @testable import EmbraceCore
    import XCTest

    class WebViewURLSanitizerTests: XCTestCase {

        // MARK: - Helpers

        private func sanitize(
            _ urlString: String,
            stripQueryParams: Bool = false,
            fragmentHandling: WebViewCaptureService.FragmentHandling = .keep
        ) -> String {
            WebViewURLSanitizer.sanitize(
                urlString,
                stripQueryParams: stripQueryParams,
                fragmentHandling: fragmentHandling
            )
        }

        /// Redacts a bare fragment and returns it without the leading `#`, to keep the pair tests readable.
        private func redactFragment(_ fragment: String) -> String {
            let result = sanitize("https://host/#" + fragment, fragmentHandling: .redact)
            return String(result.dropFirst("https://host/#".count))
        }

        /// Text with no `=` in it, used to build payloads of an exact length.
        private static let base64Body = String(
            repeating: "eyJsYXlvdXQiOnsidGl0bGUiOiJIb21lIn19",
            count: 46
        )

        /// A 1624 character base64 payload whose only `=` is the final padding character.
        private static let paddedBlob = String(base64Body.prefix(1623)) + "="

        /// The same payload at the same length, but with no padding emitted.
        private static let unpaddedBlob = String(base64Body.prefix(1624))

        // MARK: - Modes and independence

        func test_keep_leavesEveryURLUntouched() {
            let urls = [
                "https://host/",
                "https://host/path",
                "https://host/#",
                "https://host/#access_token=eyJhbGciOiJIUzI1NiJ9",
                "https://host/#/orders/123",
                "https://host/?a=1",
                "https://host/?a=1#access_token=eyJhbGciOiJIUzI1NiJ9",
                "https://host/?a=1#/orders/123"
            ]

            for url in urls {
                XCTAssertEqual(sanitize(url), url)
            }
        }

        func test_remove_dropsTheFragmentWithAndWithoutAQuery() {
            // the two leaking examples: removal must not depend on the presence of a query
            XCTAssertEqual(
                sanitize("https://host/#access_token=x", fragmentHandling: .remove),
                "https://host/"
            )
            XCTAssertEqual(
                sanitize("https://host/?a=1#access_token=x", fragmentHandling: .remove),
                "https://host/?a=1"
            )
        }

        func test_settingsAreIndependentOfEachOther() {
            let url = "https://host/path?a=1&b=2#access_token=eyJhbGciOiJIUzI1NiJ9"

            XCTAssertEqual(
                sanitize(url, stripQueryParams: false, fragmentHandling: .keep),
                url
            )
            XCTAssertEqual(
                sanitize(url, stripQueryParams: false, fragmentHandling: .redact),
                "https://host/path?a=1&b=2#access_token="
            )
            XCTAssertEqual(
                sanitize(url, stripQueryParams: false, fragmentHandling: .remove),
                "https://host/path?a=1&b=2"
            )
            XCTAssertEqual(
                sanitize(url, stripQueryParams: true, fragmentHandling: .keep),
                "https://host/path#access_token=eyJhbGciOiJIUzI1NiJ9"
            )
            XCTAssertEqual(
                sanitize(url, stripQueryParams: true, fragmentHandling: .redact),
                "https://host/path#access_token="
            )
            XCTAssertEqual(
                sanitize(url, stripQueryParams: true, fragmentHandling: .remove),
                "https://host/path"
            )
        }

        func test_strippingTheQueryDoesNotTouchTheFragment() {
            // the query is removed, the fragment survives whole, including any `?` inside it
            XCTAssertEqual(
                sanitize("https://host/?a=1#/search?q=shoes", stripQueryParams: true),
                "https://host/#/search?q=shoes"
            )

            // and a fragment is never invented for a URL that had none
            XCTAssertEqual(
                sanitize("https://host/path?a=1", stripQueryParams: true),
                "https://host/path"
            )
        }

        // MARK: - Rule 1: key/value pairs

        func test_redact_removesTheValuesOfKeyValuePairs() {
            XCTAssertEqual(
                redactFragment("access_token=eyJhbGciOiJIUzI1NiJ9&token_type=Bearer&expires_in=3600"),
                "access_token=&token_type=&expires_in="
            )
        }

        func test_redact_treatsSemicolonAsASeparator() {
            XCTAssertEqual(redactFragment("a=1;b=2"), "a=;b=")
            XCTAssertEqual(redactFragment("a=1;b=2&c=3"), "a=;b=&c=")
        }

        func test_redact_keepsParameterNamesThatAnAllowlistWouldReject() {
            XCTAssertEqual(redactFragment("mids[]=6"), "mids[]=")
            XCTAssertEqual(redactFragment("filter:name=shoes"), "filter:name=")
            XCTAssertEqual(redactFragment("user.id=42"), "user.id=")
        }

        func test_redact_dropsEverythingAfterTheFirstEquals() {
            XCTAssertEqual(redactFragment("t=a=b=c"), "t=")
        }

        func test_redact_pairWithAnEmptyNameIsNotAPair() {
            // no name to keep, so the segment falls through to the length rules
            XCTAssertEqual(redactFragment("=value"), "=value")
        }

        func test_redact_parameterNameLengthBoundary() {
            let name = String(repeating: "k", count: WebViewURLSanitizer.maxKeyLength)
            XCTAssertEqual(redactFragment(name + "=value"), name + "=")

            // one character longer is no longer a plausible name, so the segment is unstructured and,
            // at this length, a payload
            let longName = String(repeating: "k", count: WebViewURLSanitizer.maxKeyLength + 1)
            XCTAssertEqual(redactFragment(longName + "=value"), "")
        }

        // MARK: - Rule 2: hash routes

        func test_redact_keepsHashRoutes() {
            XCTAssertEqual(redactFragment("/orders/123"), "/orders/123")
            XCTAssertEqual(redactFragment("!/legacy/orders/123"), "!/legacy/orders/123")
        }

        func test_redact_recursesIntoTheQueryOfAHashRoute() {
            XCTAssertEqual(redactFragment("/search?q=shoes"), "/search?q=")
            XCTAssertEqual(redactFragment("/search?q=shoes&page=2"), "/search?q=&page=")
            XCTAssertEqual(redactFragment("/search?q=shoes;page=2"), "/search?q=;page=")
        }

        func test_redact_recursesUpToTheNestingLimit() {
            let limit = WebViewURLSanitizer.maxRecursionDepth

            // a chain of routes that bottoms out exactly at the limit still has its pair redacted
            let routes = (0..<limit).map { "/r\($0)?" }.joined()

            XCTAssertEqual(redactFragment(routes + "token=secret"), routes + "token=")
        }

        func test_redact_stopsRecursingPastTheNestingLimit() {
            let limit = WebViewURLSanitizer.maxRecursionDepth

            // a chain nested one level deeper than the limit allows, carrying a value at the bottom
            let fragment = (0...limit + 1).map { "/r\($0)?" }.joined() + "token=secret"

            // the levels up to and including the limit are kept, and everything below it is dropped rather
            // than emitted verbatim — the limit must not let an unredacted value through
            let result = redactFragment(fragment)

            XCTAssertEqual(result, (0...limit).map { "/r\($0)?" }.joined())
            XCTAssertFalse(result.contains("secret"))
        }

        func test_redact_pathologicalNestingTerminatesWithoutLeaking() {
            let fragment = String(repeating: "/x?", count: 5000) + "token=secret"

            let result = redactFragment(fragment)

            XCTAssertEqual(result, String(repeating: "/x?", count: WebViewURLSanitizer.maxRecursionDepth + 1))
            XCTAssertFalse(result.contains("secret"))
        }

        func test_redact_theNestingLimitAppliesPerBranch() {
            // each sibling segment starts at the top of the budget, so a deeply nested branch cannot consume
            // the allowance of the ones next to it
            let deep = (0...WebViewURLSanitizer.maxRecursionDepth + 1).map { "/r\($0)?" }.joined() + "token=secret"

            let result = redactFragment(deep + "&/orders/123?q=shoes")

            XCTAssertTrue(result.hasSuffix("&/orders/123?q="))
            XCTAssertFalse(result.contains("secret"))
            XCTAssertFalse(result.contains("shoes"))
        }

        func test_redact_keepsALongRouteThatWouldBeDroppedAsAPayload() {
            let route = "/" + String(repeating: "a", count: WebViewURLSanitizer.opaqueSegmentThreshold + 10)
            XCTAssertEqual(redactFragment(route), route)
        }

        // MARK: - Rules 3 and 4: unstructured segments

        func test_redact_keepsShortAnchors() {
            XCTAssertEqual(redactFragment("terms-and-conditions"), "terms-and-conditions")
            XCTAssertEqual(redactFragment("section_4.2"), "section_4.2")
        }

        func test_redact_opaqueSegmentLengthBoundary() {
            let kept = String(repeating: "a", count: WebViewURLSanitizer.opaqueSegmentThreshold)
            XCTAssertEqual(redactFragment(kept), kept)

            let dropped = String(repeating: "a", count: WebViewURLSanitizer.opaqueSegmentThreshold + 1)
            XCTAssertEqual(redactFragment(dropped), "")
        }

        func test_redact_dropsALongBase64Payload() {
            XCTAssertEqual(redactFragment(Self.unpaddedBlob), "")
        }

        // MARK: - Trap: base64 padding

        func test_redact_base64PaddingIsNotReadAsAParameterName() {
            // the only `=` in this payload is its final padding character; a naive split on `=` would read the
            // whole blob as one enormous name with an empty value and preserve it
            XCTAssertEqual(Self.paddedBlob.count, 1624)
            XCTAssertEqual(Self.paddedBlob.filter { $0 == "=" }.count, 1)
            XCTAssertEqual(redactFragment(Self.paddedBlob), "")

            // and the result must not depend on whether the payload's length happened to emit padding
            XCTAssertEqual(Self.unpaddedBlob.count, Self.paddedBlob.count)
            XCTAssertFalse(Self.unpaddedBlob.contains("="))
            XCTAssertEqual(redactFragment(Self.paddedBlob), redactFragment(Self.unpaddedBlob))
        }

        func test_redact_paddedPayloadIsDroppedAlongsideRealPairs() {
            XCTAssertEqual(
                redactFragment("state=abc&" + Self.paddedBlob + "&/orders/123"),
                "state=&&/orders/123"
            )
        }

        // MARK: - Trap: percent-encoded separators

        func test_redact_doesNotTreatEncodedSeparatorsAsSeparators() {
            // `%26` is part of the value, not a second pair
            XCTAssertEqual(redactFragment("a=1%26b=2"), "a=")
            // the same for an encoded `;` and an encoded `=`
            XCTAssertEqual(redactFragment("a=1%3Bb=2"), "a=")
            XCTAssertEqual(redactFragment("a=1%3D2"), "a=")
        }

        func test_redact_doesNotDecodeMultipleEncodingLayers() {
            // real data carries two and three layers of encoding
            XCTAssertEqual(redactFragment("filters=a%252Cb%25252Cc&page=2"), "filters=&page=")
        }

        func test_redact_neverChangesTheEncodingOfWhatItKeeps() {
            XCTAssertEqual(redactFragment("%2Fnot-a-route"), "%2Fnot-a-route")
            XCTAssertEqual(redactFragment("caf%C3%A9"), "caf%C3%A9")
            XCTAssertEqual(redactFragment("/orders%2F123?q=a%20b"), "/orders%2F123?q=")
        }

        // MARK: - Edge cases

        func test_redact_fragmentThatRedactsToNothingKeepsItsHash() {
            XCTAssertEqual(
                sanitize("https://host/#" + Self.paddedBlob, fragmentHandling: .redact),
                "https://host/#"
            )
        }

        func test_emptyFragment() {
            XCTAssertEqual(sanitize("https://host/#", fragmentHandling: .keep), "https://host/#")
            XCTAssertEqual(sanitize("https://host/#", fragmentHandling: .redact), "https://host/#")
            XCTAssertEqual(sanitize("https://host/#", fragmentHandling: .remove), "https://host/")
        }

        func test_redact_fragmentOfOnlySeparators() {
            XCTAssertEqual(redactFragment("&&"), "&&")
            XCTAssertEqual(redactFragment(";"), ";")
            XCTAssertEqual(redactFragment("a=1&&b=2"), "a=&&b=")
        }

        func test_onlyTheFirstHashDelimitsTheFragment() {
            // a later `#` is fragment data, not a second delimiter
            XCTAssertEqual(
                sanitize("https://host/#a=1#b=2", fragmentHandling: .redact),
                "https://host/#a="
            )
            XCTAssertEqual(
                sanitize("https://host/#a=1#b=2", fragmentHandling: .remove),
                "https://host/"
            )
        }

        func test_doesNotNormalizeTheURLTheWayURLComponentsWould() {
            // round tripping through `URLComponents` rewrites parts of the URL that these settings are not
            // about; the captured string must only differ in what was asked for
            let url = "https://host/pa th?a=1#access_token=x"
            XCTAssertNotEqual(URLComponents(string: url)?.string, url)

            XCTAssertEqual(
                sanitize(url, stripQueryParams: true, fragmentHandling: .remove),
                "https://host/pa th"
            )
            XCTAssertEqual(
                sanitize(url, fragmentHandling: .redact),
                "https://host/pa th?a=1#access_token="
            )
        }

        func test_reportedURL() {
            let url =
                "https://permissions.company.eu/?language_code=es-es&country_code=ESP"
                + "&app_id=6C8A3A2E-1F4B-4F3E-9F0E-6A1B2C3D4E5F#access_token=eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.abc"

            XCTAssertEqual(
                sanitize(url, fragmentHandling: .redact),
                "https://permissions.company.eu/?language_code=es-es&country_code=ESP"
                    + "&app_id=6C8A3A2E-1F4B-4F3E-9F0E-6A1B2C3D4E5F#access_token="
            )
            XCTAssertEqual(
                sanitize(url, stripQueryParams: true, fragmentHandling: .redact),
                "https://permissions.company.eu/#access_token="
            )
            XCTAssertEqual(
                sanitize(url, stripQueryParams: true, fragmentHandling: .remove),
                "https://permissions.company.eu/"
            )
        }
    }
#endif
