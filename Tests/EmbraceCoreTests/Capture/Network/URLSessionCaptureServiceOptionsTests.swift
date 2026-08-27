//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore

final class URLSessionCaptureServiceOptionsTests: XCTestCase {

    // MARK: - allowedDomains validation: empty string

    func test_allowedDomainEmptyString_Dropped() {
        let t = URLSessionCaptureService.Traceparent(onlyAllowDomains: [""])
        XCTAssertNotNil(t.onlyAllowDomains)
        XCTAssertTrue(t.onlyAllowDomains!.isEmpty)
    }

    // MARK: - allowedDomains validation: contains slash

    func test_allowedDomainContainsSlash_Dropped() {
        let t = URLSessionCaptureService.Traceparent(onlyAllowDomains: ["test.com/path"])
        XCTAssertNotNil(t.onlyAllowDomains)
        XCTAssertTrue(t.onlyAllowDomains!.isEmpty)
    }

    // MARK: - allowedDomains validation: contains whitespace

    func test_allowedDomainContainsWhitespace_Dropped() {
        let t = URLSessionCaptureService.Traceparent(onlyAllowDomains: ["test .com"])
        XCTAssertNotNil(t.onlyAllowDomains)
        XCTAssertTrue(t.onlyAllowDomains!.isEmpty)
    }

    func test_allowedDomainContainsTab_Dropped() {
        let t = URLSessionCaptureService.Traceparent(onlyAllowDomains: ["test\t.com"])
        XCTAssertNotNil(t.onlyAllowDomains)
        XCTAssertTrue(t.onlyAllowDomains!.isEmpty)
    }

    // MARK: - allowedDomains validation: leading dot

    func test_allowedDomainLeadingDot_Dropped() {
        let t = URLSessionCaptureService.Traceparent(onlyAllowDomains: [".test.com"])
        XCTAssertNotNil(t.onlyAllowDomains)
        XCTAssertTrue(t.onlyAllowDomains!.isEmpty)
    }

    // MARK: - allowedDomains validation: mixed valid and invalid

    func test_allowedDomainMixedValidAndInvalid_OnlyValidPreserved() {
        let t = URLSessionCaptureService.Traceparent(onlyAllowDomains: ["valid.com", "bad/path", "other.com"])
        XCTAssertNotNil(t.onlyAllowDomains)
        XCTAssertEqual(t.onlyAllowDomains, ["valid.com", "other.com"])
    }

    // MARK: - allowedDomains validation: all invalid

    func test_allowedDomainAllInvalid_AllowlistEmpty_StillFunctions() {
        let t = URLSessionCaptureService.Traceparent(onlyAllowDomains: ["", ".bad.com", "bad/path"])
        XCTAssertNotNil(t.onlyAllowDomains)
        XCTAssertTrue(t.onlyAllowDomains!.isEmpty)
        // Empty, not-nil allowlist means "ignore everything" — not a setup error on its own
        XCTAssertFalse(HostAllowlistMatcher.matches(host: "any.host.com", allowlist: t.onlyAllowDomains!))
    }

    // MARK: - allowedDomains validation: valid entry preserved and lowercased

    func test_allowedDomainValidEntry_PreservedAndLowercased() {
        let t = URLSessionCaptureService.Traceparent(onlyAllowDomains: ["Test.Com"])
        XCTAssertEqual(t.onlyAllowDomains, ["test.com"])
    }

    func test_allowedDomainMultipleValidEntries_AllPreserved() {
        let t = URLSessionCaptureService.Traceparent(onlyAllowDomains: ["test.com", "api.test.com"])
        XCTAssertEqual(t.onlyAllowDomains, ["test.com", "api.test.com"])
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

    func test_defaultInit_HasNilAllowedDomains() {
        let options = URLSessionCaptureService.Options()
        XCTAssertNil(options.traceparent.onlyAllowDomains)
    }

    func test_primaryInit_SetsTraceparentOptions() {
        let tp = URLSessionCaptureService.Traceparent(onlyAllowDomains: ["test.com"])
        let options = URLSessionCaptureService.Options(traceparent: tp)
        XCTAssertEqual(options.traceparent.onlyAllowDomains, ["test.com"])
    }
}
