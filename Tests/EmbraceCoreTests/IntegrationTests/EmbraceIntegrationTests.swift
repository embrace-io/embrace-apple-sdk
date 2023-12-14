//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
@testable import EmbraceIO
import EmbraceStorage
import EmbraceOTel
import GRDB
import TestSupport

final class EmbraceIntegrationTests: IntegrationTestCase {

    let options = Embrace.Options(appId: "myApp", captureServices: [])

    func test_start_createsProcessLaunchSpan() throws {
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
                let sdkStart = spanDatas.first(where: { $0.name == "emb-sdk-start" }),
                processLaunch.endTime != nil,
                sdkStart.endTime != nil {
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
