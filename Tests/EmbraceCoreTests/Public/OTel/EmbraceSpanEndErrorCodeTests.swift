//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCore
import TestSupport
import XCTest

class EmbraceSpanEndErrorCodeTests: XCTestCase {

    func end_withErrorCode() throws {
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
        XCTAssertEqual(span.attributes["emb.error_code"] as! String, "faliure")
    }

    func end_withErrorCode_nil() throws {
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
}
