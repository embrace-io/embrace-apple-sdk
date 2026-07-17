//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

final class ExperimentsHandlerTests: XCTestCase {

    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
    }

    override func tearDownWithError() throws {
        storage.coreData.destroy()
        storage = nil
    }

    private func makeHandler() -> ExperimentsHandler {
        ExperimentsHandler(storage: storage, queue: MockQueue())
    }

    private func fetchRecord() -> EmbraceMetadata? {
        storage.fetchMetadata(
            key: ExperimentsSemantics.key,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.stringValue
        )
    }

    func test_startExperiment_writesRequiredResourceRecord() throws {
        let handler = makeHandler()
        let start = Date(timeIntervalSince1970: 1_717_459_200)

        handler.startExperiment(id: "abc1", kind: .experiment, variant: "A", startedAt: start)

        let record = try XCTUnwrap(fetchRecord())
        XCTAssertEqual(record.value, "e:abc1:A:1717459200000")
        XCTAssertEqual(record.type, .requiredResource)
        XCTAssertEqual(record.lifespan, .process)
        XCTAssertEqual(record.lifespanId, ProcessIdentifier.current.stringValue)
    }

    func test_startExperiment_isNoOp_whenIdAlreadyStarted() throws {
        let handler = makeHandler()
        let start = Date(timeIntervalSince1970: 1_717_459_200)

        handler.startExperiment(id: "abc1", kind: .experiment, variant: "A", startedAt: start)
        // repeat with different kind/variant/start — must be ignored (immutable)
        handler.startExperiment(id: "abc1", kind: .featureFlag, variant: "B", startedAt: Date())

        let record = try XCTUnwrap(fetchRecord())
        XCTAssertEqual(record.value, "e:abc1:A:1717459200000")
    }

    func test_startExperiment_defaults() throws {
        let handler = makeHandler()
        let start = Date(timeIntervalSince1970: 1_717_459_200)

        handler.startExperiment(id: "abc1", startedAt: start)

        // default kind is experiment ("e") and default variant is empty
        let record = try XCTUnwrap(fetchRecord())
        XCTAssertEqual(record.value, "e:abc1::1717459200000")
    }

    func test_endExperiment_setsEndTime() throws {
        let handler = makeHandler()
        let start = Date(timeIntervalSince1970: 1_717_459_200)
        let end = Date(timeIntervalSince1970: 1_717_462_800)

        handler.startExperiment(id: "abc1", kind: .experiment, variant: "A", startedAt: start)
        handler.endExperiment(id: "abc1", endedAt: end)

        let record = try XCTUnwrap(fetchRecord())
        XCTAssertEqual(record.value, "e:abc1:A:1717459200000:1717462800000")
    }

    func test_endExperiment_isNoOp_whenAlreadyEnded() throws {
        let handler = makeHandler()
        let start = Date(timeIntervalSince1970: 1_717_459_200)
        let end = Date(timeIntervalSince1970: 1_717_462_800)

        handler.startExperiment(id: "abc1", kind: .experiment, variant: "A", startedAt: start)
        handler.endExperiment(id: "abc1", endedAt: end)
        handler.endExperiment(id: "abc1", endedAt: Date())

        let record = try XCTUnwrap(fetchRecord())
        XCTAssertEqual(record.value, "e:abc1:A:1717459200000:1717462800000")
    }

    func test_endExperiment_isNoOp_whenUnknownId() {
        let handler = makeHandler()
        handler.endExperiment(id: "unknown")
        XCTAssertNil(fetchRecord())
    }

    func test_multipleExperiments_encodedInInsertionOrder() throws {
        let handler = makeHandler()
        let start = Date(timeIntervalSince1970: 1_717_459_200)
        let start2 = Date(timeIntervalSince1970: 1_717_470_000)

        handler.startExperiment(id: "abc1", kind: .experiment, variant: "A", startedAt: start)
        handler.startExperiment(id: "def2", kind: .featureFlag, variant: nil, startedAt: start2)

        let record = try XCTUnwrap(fetchRecord())
        XCTAssertEqual(record.value, "e:abc1:A:1717459200000;f:def2::1717470000000")
    }

    func test_largeValue_storedUntruncated() throws {
        let handler = makeHandler()
        let start = Date(timeIntervalSince1970: 1_717_459_200)

        // add enough experiments to comfortably exceed the 1024-char attribute limit
        for i in 0..<200 {
            handler.startExperiment(id: "experiment-\(i)", kind: .experiment, variant: "variant", startedAt: start)
        }

        let record = try XCTUnwrap(fetchRecord())
        XCTAssertGreaterThan(record.value.count, 1024)
        XCTAssertFalse(record.value.hasSuffix("..."))
        XCTAssertEqual(record.value.components(separatedBy: ";").count, 200)
    }
}
