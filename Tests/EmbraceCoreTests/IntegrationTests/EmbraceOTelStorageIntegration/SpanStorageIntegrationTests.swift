//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore
import EmbraceOTelInternal
import EmbraceStorageInternal
import GRDB

import TestSupport

final class SpanStorageIntegrationTests: IntegrationTestCase {

    var storage: EmbraceStorage!
    let sdkStateProvider = MockEmbraceSDKStateProvider()

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
        let sessionController = MockSessionController()
        let exporter = StorageSpanExporter(options: .init(storage: storage, sessionController: sessionController), logger: MockLogger())

        EmbraceOTel.setup(spanProcessors: [SingleSpanProcessor(spanExporter: exporter, sdkStateProvider: sdkStateProvider)])
    }

    override func tearDownWithError() throws {
        _ = try storage.dbQueue.inDatabase { db in
            try SpanRecord.deleteAll(db)
        }
        try storage.teardown()
    }

    //  TESTSKIP: ValueObservation
    func skip_test_buildSpan_storesOpenSpan() throws {
        let exp = expectation(description: "Observe Insert")
        let observation = ValueObservation.tracking(SpanRecord.fetchAll)
        let cancellable = observation.start(in: storage.dbQueue) { error in
            fatalError("Error: \(error)")
        } onChange: { records in
            if records.count > 0 {
                exp.fulfill()
            }
        }

        let otel = EmbraceOTel()
        _ = otel.buildSpan(name: "example", type: .performance)
            .setAttribute(key: "foo", value: "bar")
            .startSpan()
        wait(for: [exp], timeout: 1.0)

        let records: [SpanRecord] = try storage.fetchAll()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.type, .performance)
        if let openSpan = records.first {
            XCTAssertNil(openSpan.endTime)
        }

        cancellable.cancel()
    }

    //  TESTSKIP: ValueObservation
    func skip_test_buildSpan_storesSpanThatEnded() throws {
        let exp = expectation(description: "Observe Insert")
        let observation = ValueObservation.tracking { db in
            try SpanRecord
                .filter(Column("end_time") != nil)
                .fetchAll(db)
        }
        let cancellable = observation.start(in: storage.dbQueue) { error in
            fatalError("Error: \(error)")
        } onChange: { records in
            if records.count > 0 {
                exp.fulfill()
            }
        }

        let otel = EmbraceOTel()
        let span = otel.buildSpan(name: "example", type: .performance)
            .setAttribute(key: "foo", value: "bar")
            .startSpan()

        span.end()
        wait(for: [exp], timeout: 1.0)

        let records: [SpanRecord] = try storage.fetchAll()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.type, .performance)
        if let openSpan = records.first {
            XCTAssertNotNil(openSpan.endTime)
        }

        cancellable.cancel()
    }
}
