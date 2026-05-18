//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore

final class URLSessionCaptureServiceOptionsTests: XCTestCase {

    // MARK: - allowedDomains validation: empty string

    func test_allowedDomainEmptyString_Dropped() {
        let t = URLSessionCaptureService.Traceparent(allowedDomains: [""])
        XCTAssertTrue(t.allowedDomains.isEmpty)
    }

    // MARK: - allowedDomains validation: contains slash

    func test_allowedDomainContainsSlash_Dropped() {
        let t = URLSessionCaptureService.Traceparent(allowedDomains: ["test.com/path"])
        XCTAssertTrue(t.allowedDomains.isEmpty)
    }

    // MARK: - allowedDomains validation: contains whitespace

    func test_allowedDomainContainsWhitespace_Dropped() {
        let t = URLSessionCaptureService.Traceparent(allowedDomains: ["test .com"])
        XCTAssertTrue(t.allowedDomains.isEmpty)
    }

    func test_allowedDomainContainsTab_Dropped() {
        let t = URLSessionCaptureService.Traceparent(allowedDomains: ["test\t.com"])
        XCTAssertTrue(t.allowedDomains.isEmpty)
    }

    // MARK: - allowedDomains validation: leading dot

    func test_allowedDomainLeadingDot_Dropped() {
        let t = URLSessionCaptureService.Traceparent(allowedDomains: [".test.com"])
        XCTAssertTrue(t.allowedDomains.isEmpty)
    }

    // MARK: - allowedDomains validation: mixed valid and invalid

    func test_allowedDomainMixedValidAndInvalid_OnlyValidPreserved() {
        let t = URLSessionCaptureService.Traceparent(allowedDomains: ["valid.com", "bad/path", "other.com"])
        XCTAssertEqual(t.allowedDomains, ["valid.com", "other.com"])
    }

    // MARK: - allowedDomains validation: all invalid

    func test_allowedDomainAllInvalid_AllowlistEmpty_StillFunctions() {
        let t = URLSessionCaptureService.Traceparent(allowedDomains: ["", ".bad.com", "bad/path"])
        XCTAssertTrue(t.allowedDomains.isEmpty)
        // Empty allowlist means "match everything" — not a setup error on its own
        XCTAssertTrue(HostAllowlistMatcher.matches(host: "any.host.com", allowlist: t.allowedDomains))
    }

    // MARK: - allowedDomains validation: valid entry preserved and lowercased

    func test_allowedDomainValidEntry_PreservedAndLowercased() {
        let t = URLSessionCaptureService.Traceparent(allowedDomains: ["Test.Com"])
        XCTAssertEqual(t.allowedDomains, ["test.com"])
    }

    func test_allowedDomainMultipleValidEntries_AllPreserved() {
        let t = URLSessionCaptureService.Traceparent(allowedDomains: ["test.com", "api.test.com"])
        XCTAssertEqual(t.allowedDomains, ["test.com", "api.test.com"])
    }

    // MARK: - injectTracingHeader deprecation

    func test_deprecatedGetter_AlwaysReturnsFalse() {
        let options = URLSessionCaptureService.Options()
        XCTAssertFalse(options.injectTracingHeader)
    }

    func test_deprecatedSetter_IsNoOp() {
        let options = URLSessionCaptureService.Options()
        options.injectTracingHeader = true
        // Setter is a no-op — getter still returns false
        XCTAssertFalse(options.injectTracingHeader)
    }

    // MARK: - Options init

    func test_defaultInit_HasEmptyAllowedDomains() {
        let options = URLSessionCaptureService.Options()
        XCTAssertTrue(options.traceparent.allowedDomains.isEmpty)
    }

    func test_primaryInit_SetsTraceparentOptions() {
        let tp = URLSessionCaptureService.Traceparent(allowedDomains: ["test.com"])
        let options = URLSessionCaptureService.Options(traceparent: tp)
        XCTAssertEqual(options.traceparent.allowedDomains, ["test.com"])
    }
}
