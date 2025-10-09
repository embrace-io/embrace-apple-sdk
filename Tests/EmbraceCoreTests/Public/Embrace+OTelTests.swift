//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore

@MainActor
final class Embrace_OTelTests: XCTestCase {

    var client: Embrace!

    override func setUp() async throws {
        client = try Embrace(
            options: .init(appId: "debug", captureServices: [], crashReporter: nil),
            embraceStorage: .createInMemoryDb()
        )
    }

    override func tearDown() async throws {
        client = nil
    }

    func test_tracer_retrievesTracerInstance() throws {
        let tracer = client.tracer(instrumentationName: "ExampleTracer")
        XCTAssertNotNil(tracer)

    }
}
