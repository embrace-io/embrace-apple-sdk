//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
import EmbraceStorage
import EmbraceOTel

final class EmbraceIntegrationTests: XCTestCase {

    let options = Embrace.Options(appId: "myApp", captureServices: [])

    override func setUpWithError() throws {
        if let baseURL = EmbraceFileSystem.rootURL() {
            try? FileManager.default.removeItem(at: baseURL)
        }
    }

    override func tearDownWithError() throws {
        if let baseURL = EmbraceFileSystem.rootURL() {
            try? FileManager.default.removeItem(at: baseURL)
        }
    }

    override func tearDown() {
        Embrace.client = nil
    }

    func test_start_createsProcessLaunchSpan() throws {
        try Embrace.setup(options: options)

        try Embrace.client!.start()

        let storage = Embrace.client!.storage
        let spans: [SpanRecord] = try storage.fetchAll()
        let spanDatas = try spans.map { record in
            try JSONDecoder().decode(SpanData.self, from: record.data)
        }

        let processLaunchSpan = spanDatas.first { $0.name == "emb-process-launch" }
        let sdkStartSpan = spanDatas.first { $0.name == "emb-sdk-start" }

        XCTAssertNotNil(processLaunchSpan)
        XCTAssertNotNil(sdkStartSpan)
        XCTAssertEqual(sdkStartSpan?.parentSpanId, processLaunchSpan?.spanId)
        XCTAssertEqual(sdkStartSpan?.traceId, processLaunchSpan?.traceId)
    }

}
