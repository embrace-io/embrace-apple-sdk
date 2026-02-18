////
////  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
////
//
//import EmbraceStorageInternal
//import OpenTelemetryApi
//import OpenTelemetrySdk
//import TestSupport
//import XCTest
//
//@testable import EmbraceCore
//@testable import EmbraceOTelInternal
//
//final class GenericLogExporterTests: XCTestCase {
//
//    let sdkStateProvider = MockEmbraceSDKStateProvider()
//
//    func test_genericExporter_isCalled_whenConfiguredInSharedState() throws {
//        let exporter = InMemoryLogRecordExporter()
//        let sharedState = DefaultEmbraceLogSharedState.create(
//            exporter: exporter,
//            sdkStateProvider: sdkStateProvider
//        )
//        EmbraceOTel.setup(logSharedState: sharedState)
//
//        EmbraceOTel().logger
//            .logRecordBuilder()
//            .setBody(.string("example log message"))
//            .emit()
//
//        let exportedLogRecord = exporter.finishedLogRecords.first
//        XCTAssertNotNil(exportedLogRecord)
//        XCTAssertEqual(exportedLogRecord?.body, .string("example log message"))
//    }
//
//}
