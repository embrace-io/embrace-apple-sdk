//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import OpenTelemetryApi

@testable import EmbraceOTel

class EmbraceLoggerBuilderTests: XCTestCase {
    private var sut: EmbraceLoggerBuilder!
    private var result: Logger!

    func test_onBuild_createsEmbraceLogger() {
        givenEmbraceLoggerBuilder()
        whenInvokingBuild()
    }

    func givenEmbraceLoggerBuilder() {
        sut = EmbraceLoggerBuilder(sharedState: .init(resource: .init(),
                                                      config: DefaultEmbraceLoggerConfig(),
                                                      processors: []))
    }

    func whenInvokingBuild() {
        result = sut.build()
    }

    func thenLoggerIsEmbraceLogger() {
        XCTAssertTrue(result is EmbraceLogger)
    }
}
