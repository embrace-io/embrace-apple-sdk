//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCommonInternal

class CrashSignalTests: XCTestCase {

    func test_from_stringValue_roundTripsEveryCase() {
        // a typo in either the `from(string:)` or `stringValue` table breaks the round-trip
        for signal in CrashSignal.allCases {
            XCTAssertEqual(
                CrashSignal.from(string: signal.stringValue),
                signal,
                "round-trip failed for \(signal.stringValue)"
            )
        }
    }

    func test_from_isCaseInsensitive() {
        XCTAssertEqual(CrashSignal.from(string: "sigsegv"), .SIGSEGV)
        XCTAssertEqual(CrashSignal.from(string: "SigAbrt"), .SIGABRT)
    }

    func test_from_unknownOrEmptyString_returnsNil() {
        XCTAssertNil(CrashSignal.from(string: "SIGFOO"))
        XCTAssertNil(CrashSignal.from(string: ""))
    }
}
