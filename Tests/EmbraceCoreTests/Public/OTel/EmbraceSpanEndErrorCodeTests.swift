//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCore
import TestSupport
import XCTest

class EmbraceSpanEndErrorCodeTests: XCTestCase {

    func test_end_withErrorCode_failure() throws {
        // given a span
        let span = MockSpan(name: "test")

        // when ending it with an error code
        let endTime = Date(timeIntervalSince1970: 50)
        span.end(errorCode: .failure, endTime: endTime)

        // then it ends correctly
        // the status is set to "error"
        // and has the error code attribute
        XCTAssertEqual(span.endTime, endTime)
        XCTAssertEqual(span.status, .error)
        XCTAssertEqual(span.attributes["emb.error_code"] as! String, "failure")
    }

    func test_end_withErrorCode_userAbandon() throws {
        // given a span
        let span = MockSpan(name: "test")

        // when ending it with the user-abandon error code
        let endTime = Date(timeIntervalSince1970: 50)
        span.end(errorCode: .userAbandon, endTime: endTime)

        // then it ends correctly with status "error" and the matching attribute
        XCTAssertEqual(span.endTime, endTime)
        XCTAssertEqual(span.status, .error)
        XCTAssertEqual(span.attributes["emb.error_code"] as! String, "user_abandon")
    }

    func test_end_withErrorCode_unknown() throws {
        // given a span
        let span = MockSpan(name: "test")

        // when ending it with the unknown error code
        let endTime = Date(timeIntervalSince1970: 50)
        span.end(errorCode: .unknown, endTime: endTime)

        // then it ends correctly with status "error" and the matching attribute
        XCTAssertEqual(span.endTime, endTime)
        XCTAssertEqual(span.status, .error)
        XCTAssertEqual(span.attributes["emb.error_code"] as! String, "unknown")
    }

    func test_end_withErrorCode_nil() throws {
        // given a span
        let span = MockSpan(name: "test")

        // when ending it with an error code
        let endTime = Date(timeIntervalSince1970: 50)
        span.end(errorCode: nil, endTime: endTime)

        // then it ends correctly
        // the status is set to "ok"
        // and it doesn't have the error code attribute
        XCTAssertEqual(span.endTime, endTime)
        XCTAssertEqual(span.status, .ok)
        XCTAssertNil(span.attributes["emb.error_code"])
    }

    func test_end_withErrorCode_afterEnd_returnsEarlyWithoutAttemptingChanges() throws {
        // given a span that already ended
        let endTime = Date(timeIntervalSince1970: 50)
        let span = MockSpan(name: "test", endTime: endTime)

        // when ending it again with an error code
        span.end(errorCode: .failure, endTime: Date(timeIntervalSince1970: 100))

        // then it keeps the outcome it ended with
        XCTAssertEqual(span.endTime, endTime)
        XCTAssertEqual(span.status, .unset)
        XCTAssertNil(span.attributes["emb.error_code"])

        // and none of the individual steps was attempted, so a single call can't report the
        // same thing once per step
        XCTAssertEqual(span.ignoredMutationCount, 0)
    }
}
