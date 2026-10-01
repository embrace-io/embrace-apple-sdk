//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceOTelInternal

class EmbraceLogRecordProcessorArrayExtensionTests: XCTestCase {

    let sdkStateProvider = MockEmbraceSDKStateProvider()

    func test_onDefaultWithExporters_returnSingleLogRecordProcessorInstance() throws {
        let processors: [LogRecordProcessor] = .default(sdkStateProvider: sdkStateProvider)
        XCTAssertEqual(processors.count, 1)
        XCTAssertTrue(try XCTUnwrap(processors.first) is SingleLogRecordProcessor)
    }

    func test_onDefaultWithCustomerExporter_queuesOnlyTheCustomerExporter() throws {
        let embraceExporter = InMemoryLogRecordExporter()
        let customerExporter = InMemoryLogRecordExporter()
        let processors: [LogRecordProcessor] = .default(
            embraceExporters: [embraceExporter],
            exporters: [customerExporter],
            sdkStateProvider: sdkStateProvider
        )

        XCTAssertEqual(processors.count, 2)
        XCTAssertTrue(processors[0] is SingleLogRecordProcessor)
        let queued = try XCTUnwrap(processors[1] as? QueuedLogRecordProcessor)

        // Hold the customer queue so anything forwarded through it can't run yet.
        let gate = DispatchSemaphore(value: 0)
        queued.queue.async {
            // timed-wait: deadlock guard so a failing assertion below doesn't hang the run.
            _ = gate.wait(timeout: .now() + TimeInterval.defaultTimeout)
        }

        processors.forEach { $0.onEmit(logRecord: .log(withTestId: "12345")) }

        XCTAssertEqual(embraceExporter.finishedLogRecords.count, 1)
        XCTAssertEqual(customerExporter.finishedLogRecords.count, 0)

        gate.signal()
        _ = queued.forceFlush()

        XCTAssertEqual(try customerExporter.finishedLogRecords.first?.getTestId(), "12345")
    }

    func test_onDefaultWithCustomerProcessor_queuesTheCustomerProcessor() throws {
        let processors: [LogRecordProcessor] = .default(
            processors: [SpyLoggerProcessor()],
            sdkStateProvider: sdkStateProvider
        )

        XCTAssertEqual(processors.count, 2)
        XCTAssertTrue(processors[1] is QueuedLogRecordProcessor)
    }
}
