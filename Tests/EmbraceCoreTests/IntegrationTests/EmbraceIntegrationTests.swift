//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
import EmbraceStorageInternal
import EmbraceOTelInternal
import GRDB
import TestSupport

final class EmbraceIntegrationTests: IntegrationTestCase {

    let options = Embrace.Options(appId: "myApp", captureServices: [], crashReporter: nil)

    //  TESTSKIP: This test is flakey in CI. It seems the value observation in the DB is not consistent
    //  May want to introduce and `Embrace.shutdown` method that will flush the SpanProcessor.
    //  This will allow us to not need to perform the value observation and also not wait an arbitrary
    //  amount of time for the spans to be processed/exported.
    func skip_test_start_createsProcessLaunchSpan() throws {
        var processLaunchSpan: SpanData?
        var sdkStartSpan: SpanData?
        try Embrace.setup(options: options)

        let expectation = expectation(description: "wait for span records")
        let observation = ValueObservation.tracking(SpanRecord.fetchAll)

        let cancellable = observation.start(in: Embrace.client!.storage.dbQueue) { error in
            XCTAssert(false, error.localizedDescription)
        } onChange: { records in
            let spanDatas = (try? records.map { record in
                try JSONDecoder().decode(SpanData.self, from: record.data)
            }) ?? []

            if let processLaunch = spanDatas.first(where: { $0.name == "emb-process-launch" }),
                let sdkStart = spanDatas.first(where: { $0.name == "emb-sdk-start" }) {
                    processLaunchSpan = processLaunch
                    sdkStartSpan = sdkStart
                    expectation.fulfill()
            }
        }

        // When
        try Embrace.client!.start()

        wait(for: [expectation], timeout: .defaultTimeout)

        XCTAssertNotNil(processLaunchSpan)
        XCTAssertNotNil(sdkStartSpan)
        XCTAssertNotNil(processLaunchSpan)
        XCTAssertNotNil(sdkStartSpan)
        XCTAssertEqual(sdkStartSpan?.parentSpanId, processLaunchSpan?.spanId)
        XCTAssertEqual(sdkStartSpan?.traceId, processLaunchSpan?.traceId)

        cancellable.cancel()
    }
}
