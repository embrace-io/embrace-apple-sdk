//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
@testable import EmbraceOTelInternal
import EmbraceStorageInternal
import TestSupport
import OpenTelemetryApi
import OpenTelemetrySdk

final class GenericLogExporterTests: XCTestCase {
    class DummyLogControllable: LogControllable {
        func uploadAllPersistedLogs() {}
        func batchFinished(withLogs logs: [LogRecord]) {}
    }

    func test_genericExporter_isCalled_whenConfiguredInSharedState() throws {
        let exporter = InMemoryLogRecordExporter()
        let sharedState = DefaultEmbraceLogSharedState.create(
            storage: try .createInMemoryDb(),
            controller: DummyLogControllable(),
            exporter: exporter
        )
        EmbraceOTel.setup(logSharedState: sharedState)

        EmbraceOTel().logger
            .logRecordBuilder()
            .setBody(.string("example log message"))
            .emit()

        let exportedLogRecord = exporter.finishedLogRecords.first
        XCTAssertNotNil(exportedLogRecord)
        XCTAssertEqual(exportedLogRecord?.body, .string("example log message"))
    }

}
