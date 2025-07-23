//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore

final class Embrace_OTelTests: XCTestCase {

    var client: Embrace!

    override func setUpWithError() throws {
        client = try Embrace(
            options: .init(appId: "debug", captureServices: [], crashReporter: nil),
            embraceStorage: .createInMemoryDb()
        )
    }

    override func tearDownWithError() throws {
        client = nil
    }

    func test_tracer_retrievesTracerInstance() throws {
        let tracer = client.tracer(instrumentationName: "ExampleTracer")
        XCTAssertNotNil(tracer)

    }
}
