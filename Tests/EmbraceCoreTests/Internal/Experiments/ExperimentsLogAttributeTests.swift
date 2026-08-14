//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceConfiguration
import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceStorageInternal

/// Setting the value as a log attribute is what makes it reach every consumer at once: it is stored on
/// the log record, so it travels into the upload payload, and it is on the `ReadableLogRecord` handed
/// to a customer's own log processors and exporters.
final class ExperimentsLogAttributeTests: XCTestCase {

    var storage: EmbraceStorage!
    var sessionController: MockSessionController!
    var controller: LogController!
    var handler: ExperimentsHandler!
    var otel: MockEmbraceOTelBridge!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
        sessionController = MockSessionController()
        sessionController.startSession(state: .foreground)

        controller = LogController(storage: storage, upload: nil, controller: sessionController)
        controller.sdkStateProvider = MockEmbraceSDKStateProvider()

        handler = ExperimentsHandler(
            storage: storage,
            experimentsLimits: ExperimentsLimits(),
            configNotificationCenter: NotificationCenter(),
            logger: MockLogger()
        )
        controller.experiments = handler

        otel = MockEmbraceOTelBridge()
        controller.otel = otel
    }

    override func tearDownWithError() throws {
        storage.coreData.destroy()
        storage = nil
        controller = nil
        handler = nil
    }

    private func createLog() -> [String: String] {
        let expectation = expectation(description: "log created")
        let queue = DispatchQueue(label: "test")

        controller.createLog("message", severity: .info, queue: queue)
        queue.async { expectation.fulfill() }
        wait(for: [expectation], timeout: .defaultTimeout)

        guard let log = otel.otel.logs.last else {
            return [:]
        }
        return log.attributes.reduce(into: [:]) { result, entry in
            result[entry.key] = entry.value.description
        }
    }

    func test_log_carriesTheTrackedExperiments() {
        handler.trackExperiments([.init(id: "exp", variant: "A", startedAt: Date(timeIntervalSince1970: 1000))])

        XCTAssertEqual(createLog()[LogSemantics.keyExperiments], "e:exp:A:1000000")
    }

    func test_log_withNothingTracked_hasNoAttribute() {
        XCTAssertNil(createLog()[LogSemantics.keyExperiments])
    }

    /// The storage write is asynchronous, so a log emitted right after a tracking call has to read the
    /// value from memory rather than waiting for the record to land.
    func test_log_doesNotWaitForTheStorageWrite() {
        handler.trackExperiments([.init(id: "exp", startedAt: Date(timeIntervalSince1970: 1000))])

        // deliberately no wait for the core data write
        XCTAssertEqual(createLog()[LogSemantics.keyExperiments], "e:exp::1000000")
    }

    func test_log_reflectsTheLatestState() {
        handler.trackExperiments([.init(id: "exp", startedAt: Date(timeIntervalSince1970: 1000))])
        XCTAssertEqual(createLog()[LogSemantics.keyExperiments], "e:exp::1000000")

        handler.untrackExperiments(ids: ["exp"], endedAt: Date(timeIntervalSince1970: 2000))
        XCTAssertEqual(createLog()[LogSemantics.keyExperiments], "e:exp::1000000:2000000")
    }
}

final class ExperimentsLogAttributesBuilderTests: XCTestCase {

    func test_addExperiments_setsTheAttribute() {
        let builder = EmbraceLogAttributesBuilder(session: nil, initialAttributes: [:])
        let attributes = builder.addExperiments("e:exp::1000000").build()

        XCTAssertEqual(attributes[LogSemantics.keyExperiments], "e:exp::1000000")
    }

    func test_addExperiments_withNil_setsNothing() {
        let builder = EmbraceLogAttributesBuilder(session: nil, initialAttributes: [:])
        let attributes = builder.addExperiments(nil).build()

        XCTAssertNil(attributes[LogSemantics.keyExperiments])
    }

    func test_addExperiments_doesNotOverrideAnExistingValue() {
        let builder = EmbraceLogAttributesBuilder(
            session: nil,
            initialAttributes: [LogSemantics.keyExperiments: "existing"]
        )
        let attributes = builder.addExperiments("e:exp::1000000").build()

        XCTAssertEqual(attributes[LogSemantics.keyExperiments], "existing")
    }
}
