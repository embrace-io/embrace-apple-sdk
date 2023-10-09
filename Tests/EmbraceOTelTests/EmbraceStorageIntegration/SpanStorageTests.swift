//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceOTel
import EmbraceStorage
import GRDB

import TestSupport

final class SpanStorageTests: XCTestCase {

    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        let storageOptions = EmbraceStorage.Options(named: "span-storage")
        storage = try EmbraceStorage(options: storageOptions)

        EmbraceOTel.setup(storage: storage)
    }

    func skip_test_addSpan_storesSpan() throws {
        let otel = EmbraceOTel()
        _ = otel.addSpan(name: "example", type: .performance) {  5 * 5 }

        let exp = expectation(description: "Observe Insert")

        let observation = ValueObservation.tracking(SpanRecord.fetchAll)
        let cancellable = observation.start(in: storage.dbQueue) { error in
            fatalError("Error: \(error)")
        } onChange: { records in
            if records.count > 0 {
                exp.fulfill()
            }
        }

        wait(for: [exp], timeout: 1.0)

        let records: [SpanRecord] = try storage.fetchAll()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.type, .performance)

        cancellable.cancel()
    }
}
