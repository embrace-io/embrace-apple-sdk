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
/// the log record, so it travels into the upload payload, and it is on the log handed to a customer's
/// own log processors and exporters.
final class ExperimentsLogAttributeTests: XCTestCase {

    var storage: EmbraceStorage!
    var sessionController: MockSessionController!
    var controller: LogController!
    var handler: ExperimentsHandler!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
        sessionController = MockSessionController()
        sessionController.startSession(state: .foreground)

        controller = LogController(
            storage: storage,
            upload: nil,
            sessionController: sessionController,
            queue: DispatchQueue(label: "io.embrace.experiments.log.tests")
        )
        controller.sdkStateProvider = MockEmbraceSDKStateProvider()

        handler = ExperimentsHandler(
            storage: storage,
            experimentsLimits: ExperimentsLimits(),
            configNotificationCenter: NotificationCenter(),
            logger: MockLogger()
        )
        controller.experiments = handler
    }

    override func tearDownWithError() throws {
        controller = nil
        handler = nil
        sessionController = nil
        storage.coreData.destroy()
        storage = nil
    }

    /// Creates a log through the controller and returns the attributes it ended up with.
    private func createLog() throws -> EmbraceAttributes {
        let expectation = expectation(description: "log created")
        var attributes: EmbraceAttributes = [:]

        controller.createLog("message", severity: .info) { log in
            attributes = log?.attributes ?? [:]
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
        return attributes
    }

    private func experiments(in attributes: EmbraceAttributes) -> String? {
        attributes[LogSemantics.keyExperiments]?.description
    }

    func test_log_carriesTheTrackedExperiments() throws {
        handler.trackExperiments([.init(id: "exp", variant: "A", startedAt: Date(timeIntervalSince1970: 1000))])

        XCTAssertEqual(experiments(in: try createLog()), "e:exp:A:1000000")
    }

    func test_log_withNothingTracked_hasNoAttribute() throws {
        XCTAssertNil(experiments(in: try createLog()))
    }

    /// The storage write is asynchronous, so a log emitted right after a tracking call has to read the
    /// value from memory rather than waiting for the record to land.
    func test_log_doesNotWaitForTheStorageWrite() throws {
        handler.trackExperiments([.init(id: "exp", startedAt: Date(timeIntervalSince1970: 1000))])

        // deliberately no wait for the core data write
        XCTAssertEqual(experiments(in: try createLog()), "e:exp::1000000")
    }

    func test_log_reflectsTheLatestState() throws {
        handler.trackExperiments([.init(id: "exp", startedAt: Date(timeIntervalSince1970: 1000))])
        XCTAssertEqual(experiments(in: try createLog()), "e:exp::1000000")

        handler.untrackExperiments(ids: ["exp"], endedAt: Date(timeIntervalSince1970: 2000))
        XCTAssertEqual(experiments(in: try createLog()), "e:exp::1000000:2000000")
    }
}

/// Logs that come in through the OTel bridge never reach `LogController.createLog`, so they are
/// stamped on the way in instead. They have to carry the attribute like any other log.
final class ExperimentsBridgeLogAttributeTests: XCTestCase {

    var storage: EmbraceStorage!
    var sessionController: MockSessionController!
    var logController: LogController!
    var handler: DefaultOTelSignalsHandler!
    var experiments: ExperimentsHandler!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()

        sessionController = MockSessionController()
        sessionController.storage = storage

        logController = LogController(
            storage: storage,
            upload: nil,
            sessionController: sessionController,
            queue: .main
        )

        experiments = ExperimentsHandler(
            storage: storage,
            experimentsLimits: ExperimentsLimits(),
            configNotificationCenter: NotificationCenter(),
            logger: MockLogger()
        )
        logController.experiments = experiments

        // The real sanitizer, so the length-limit exemption is actually exercised.
        handler = DefaultOTelSignalsHandler(
            storage: storage,
            sessionController: sessionController,
            logController: logController,
            limiter: MockOTelSignalsLimiter(),
            bridge: MockOTelSignalBridge()
        )

        sessionController.spanHandler = handler
        sessionController.startSession(state: .foreground)
    }

    override func tearDownWithError() throws {
        handler = nil
        logController = nil
        experiments = nil
        sessionController = nil
        storage.coreData.destroy()
        storage = nil
    }

    /// Emits a log the way the bridge does and returns the attributes it was stored with.
    private func emitLog(attributes: EmbraceAttributes = [:]) throws -> EmbraceAttributes {
        handler.onEmitLog(MockLog(attributes: attributes))
        wait(delay: .defaultTimeout)

        let stored = try XCTUnwrap(storage.fetchAllLogs().first)
        return stored.attributes
    }

    func test_bridgeLog_carriesTheTrackedExperiments() throws {
        experiments.trackExperiments([.init(id: "exp", variant: "A", startedAt: Date(timeIntervalSince1970: 1000))])

        let attributes = try emitLog()
        XCTAssertEqual(attributes[LogSemantics.keyExperiments]?.description, "e:exp:A:1000000")
    }

    func test_bridgeLog_withNothingTracked_hasNoAttribute() throws {
        let attributes = try emitLog()
        XCTAssertNil(attributes[LogSemantics.keyExperiments])
    }

    /// Stamped after sanitization, so the value is exempt from the attribute value length limit.
    /// Length comes from the number of records, since `id` and `variant` are each capped at 128.
    func test_bridgeLog_longValue_isNotTruncated() throws {
        let variant = String(repeating: "a", count: 100)
        experiments.trackExperiments(
            (0..<20).map {
                .init(id: "exp\($0)", variant: variant, startedAt: Date(timeIntervalSince1970: 1000))
            }
        )

        let attributes = try emitLog()
        let value = try XCTUnwrap(attributes[LogSemantics.keyExperiments]?.description)

        XCTAssertEqual(value, experiments.encodedExperiments)
        XCTAssertGreaterThan(value.count, 1024)
    }

    /// A value the emitter already set is left alone.
    func test_bridgeLog_doesNotOverrideAnExistingValue() throws {
        experiments.trackExperiments([.init(id: "exp", startedAt: Date(timeIntervalSince1970: 1000))])

        let attributes = try emitLog(attributes: [LogSemantics.keyExperiments: "e:kept::1"])
        XCTAssertEqual(attributes[LogSemantics.keyExperiments]?.description, "e:kept::1")
    }
}

final class ExperimentsLogAttributesBuilderTests: XCTestCase {

    func test_addExperiments_setsTheAttribute() {
        let builder = EmbraceLogAttributesBuilder(session: nil, initialAttributes: [:])
        let attributes = builder.addExperiments("e:exp::1000000").build()

        XCTAssertEqual(attributes[LogSemantics.keyExperiments]?.description, "e:exp::1000000")
    }

    func test_addExperiments_withNil_setsNothing() {
        let builder = EmbraceLogAttributesBuilder(session: nil, initialAttributes: [:])
        let attributes = builder.addExperiments(nil).build()

        XCTAssertNil(attributes[LogSemantics.keyExperiments])
    }

    func test_addExperiments_doesNotOverrideAnExistingValue() {
        let builder = EmbraceLogAttributesBuilder(
            session: nil,
            initialAttributes: [LogSemantics.keyExperiments: "e:kept::1"]
        )
        let attributes = builder.addExperiments("e:ignored::2").build()

        XCTAssertEqual(attributes[LogSemantics.keyExperiments]?.description, "e:kept::1")
    }
}
