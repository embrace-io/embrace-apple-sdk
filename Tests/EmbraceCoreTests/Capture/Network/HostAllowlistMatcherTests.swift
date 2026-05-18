//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore

final class HostAllowlistMatcherTests: XCTestCase {

    // MARK: - nil host

    func test_nilHost_ReturnsFalse() {
        XCTAssertFalse(HostAllowlistMatcher.matches(host: nil, allowlist: ["test.com"]))
    }

    func test_nilHost_EmptyAllowlist_ReturnsFalse() {
        XCTAssertFalse(HostAllowlistMatcher.matches(host: nil, allowlist: []))
    }

    // MARK: - Empty allowlist

    func test_emptyAllowlist_ReturnsTrue() {
        XCTAssertTrue(HostAllowlistMatcher.matches(host: "any.host.com", allowlist: []))
    }

    // MARK: - Bare domain matching

    func test_bareEntry_MatchesBareDomain() {
        XCTAssertTrue(HostAllowlistMatcher.matches(host: "test.com", allowlist: ["test.com"]))
    }

    func test_bareEntry_MatchesAllSubdomains() {
        XCTAssertTrue(HostAllowlistMatcher.matches(host: "api.test.com", allowlist: ["test.com"]))
        XCTAssertTrue(HostAllowlistMatcher.matches(host: "cdn.test.com", allowlist: ["test.com"]))
        XCTAssertTrue(HostAllowlistMatcher.matches(host: "foo.bar.test.com", allowlist: ["test.com"]))
    }

    // MARK: - Suffix attack rejection

    func test_bareEntry_DoesNotMatchSimilarSuffix() {
        // "target.com" entry must not match "failtest.com" (naive hasSuffix would match)
        XCTAssertFalse(HostAllowlistMatcher.matches(host: "failtest.com", allowlist: ["test.com"]))
        // "target.com" entry must not match "test.com.fail.com"
        XCTAssertFalse(HostAllowlistMatcher.matches(host: "test.com.fail.com", allowlist: ["test.com"]))
    }

    // MARK: - Case insensitivity

    func test_caseInsensitive_MatchesUppercaseHost() {
        XCTAssertTrue(HostAllowlistMatcher.matches(host: "API.Test.Com", allowlist: ["test.com"]))
        XCTAssertTrue(HostAllowlistMatcher.matches(host: "TEST.COM", allowlist: ["test.com"]))
    }

    // MARK: - Multiple entries

    func test_multipleEntries_FirstHitWins() {
        XCTAssertTrue(HostAllowlistMatcher.matches(
            host: "api.sometest.com",
            allowlist: ["test.com", "sometest.com", "othertest.com"]
        ))
    }

    // MARK: - Unrelated host

    func test_unrelatedHost_ReturnsFalse() {
        XCTAssertFalse(HostAllowlistMatcher.matches(host: "notinlist.com", allowlist: ["test.com", "othertest.com"]))
    }
}
