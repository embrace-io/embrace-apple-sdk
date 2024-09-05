//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import EmbraceCore
import EmbraceOTelInternal
import TestSupport

final class Embrace_OTelIntegrationTests: IntegrationTestCase {

// MARK: recordCompletedSpan
    func test_recordCompletedSpan_setsStatus_toOk() throws {
        throw XCTSkip()

        let exporter = InMemorySpanExporter()
        let embrace = try Embrace.setup(options: .init(
            appId: "myApp",
            captureServices: [],
            crashReporter: nil,
            export: .init(spanExporter: exporter)
        )).start()

        embrace.recordCompletedSpan(
            name: "my-example-span",
            type: .performance,
            parent: nil,
            startTime: Date(),
            endTime: Date(),
            attributes: [:],
            events: [],
            errorCode: nil
        )

        let expectation = expectation(description: "export completes")
        exporter.onExportComplete {
            if let result = exporter.exportedSpans.values.first(where: { value in
                value.name == "my-example-span"
            }) {
                XCTAssertEqual(result.status, .ok)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 6.0)
    }

    func test_recordCompletedSpan_withErrorCode_setsStatus_toError() throws {
        throw XCTSkip()

        let exporter = InMemorySpanExporter()
        let embrace = try Embrace.setup(options: .init(
            appId: "myApp",
            captureServices: [],
            crashReporter: nil,
            export: .init(spanExporter: exporter)
        ))

        embrace.recordCompletedSpan(
            name: "my-example-span",
            type: .performance,
            parent: nil,
            startTime: Date(),
            endTime: Date(),
            attributes: [:],
            events: [],
            errorCode: .userAbandon
        )

        let expectation = expectation(description: "export completes")
        exporter.onExportComplete {
            if let result = exporter.exportedSpans.values.first(where: { value in
                value.name == "my-example-span"
            }) {
                XCTAssertEqual(result.status, .error(description: "userAbandon"))
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 6.0)
    }

}
