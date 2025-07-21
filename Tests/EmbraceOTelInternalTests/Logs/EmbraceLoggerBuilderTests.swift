//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import XCTest

@testable import EmbraceOTelInternal

class EmbraceLoggerBuilderTests: XCTestCase {
    private var sut: EmbraceLoggerBuilder!
    private var result: Logger!

    func test_onBuild_createsEmbraceLogger() {
        givenEmbraceLoggerBuilder()
        whenInvokingBuild()
        thenLoggerIsEmbraceLogger()
    }
}

extension EmbraceLoggerBuilderTests {
    func givenEmbraceLoggerBuilder() {
        sut = EmbraceLoggerBuilder(sharedState: MockEmbraceLogSharedState())
    }

    func whenInvokingBuild() {
        result = sut.build()
    }

    func thenLoggerIsEmbraceLogger() {
        XCTAssertTrue(result is EmbraceLogger)
    }
}
