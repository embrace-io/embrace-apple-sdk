//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceConfiguration
import EmbraceSemantics
import OpenTelemetryApi
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceStorageInternal

/// Experiments are stored as a required resource so a later process can read back the value of the
/// process that produced it. That storage record must never become a resource attribute — the value
/// is reported as an attribute of the session span and of each log instead.
final class ExperimentsResourceProviderTests: XCTestCase {

    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
    }

    override func tearDownWithError() throws {
        storage.coreData.destroy()
        storage = nil
    }

    private func makeHandler() -> ExperimentsHandler {
        ExperimentsHandler(
            storage: storage,
            experimentsLimits: ExperimentsLimits(),
            configNotificationCenter: NotificationCenter(),
            logger: MockLogger(),
            persistDebounceInterval: 0
        )
    }

    func test_getResource_neverIncludesExperiments() {
        // given experiments stored for the current process
        storage.addMetadata(
            key: SpanSemantics.keyExperiments,
            value: "e:exp:A:1000000",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.stringValue
        )

        // then they are absent from the otel resource
        let resource = ResourceStorageExporter(storage: storage).getResource()
        XCTAssertNil(resource.attributes[SpanSemantics.keyExperiments])
    }

    /// Guards the whole write path, not just a hand-written storage record.
    func test_getResource_neverIncludesExperimentsWrittenByTheHandler() {
        let handler = makeHandler()
        handler.trackExperiments([.init(id: "exp", variant: "A", startedAt: Date(timeIntervalSince1970: 1000))])
        wait(delay: .shortTimeout)

        // the handler did write the record
        XCTAssertNotNil(
            storage.fetchMetadata(
                key: SpanSemantics.keyExperiments,
                type: .requiredResource,
                lifespan: .process,
                lifespanId: ProcessIdentifier.current.stringValue
            )
        )

        // but it does not reach the otel resource
        let resource = ResourceStorageExporter(storage: storage).getResource()
        XCTAssertNil(resource.attributes[SpanSemantics.keyExperiments])
    }

    func test_getResource_stillIncludesEveryOtherResource() {
        storage.addMetadata(
            key: SpanSemantics.keyExperiments,
            value: "e:exp:A:1000000",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.stringValue
        )
        storage.addMetadata(
            key: "other",
            value: "value",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.stringValue
        )

        let attributes = ResourceStorageExporter(storage: storage).getResource().attributes

        XCTAssertNil(attributes[SpanSemantics.keyExperiments])
        XCTAssertEqual(attributes["other"]?.description, "value")
    }

    // MARK: - Process scoping

    func test_getResource_excludesProcessResourcesFromOtherProcesses() {
        let otherProcess = EmbraceIdentifier.random

        storage.addMetadata(
            key: "mine",
            value: "current",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.stringValue
        )
        storage.addMetadata(
            key: "theirs",
            value: "other",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: otherProcess.stringValue
        )

        let attributes = ResourceStorageExporter(storage: storage).getResource().attributes

        XCTAssertEqual(attributes["mine"]?.description, "current")
        XCTAssertNil(attributes["theirs"])
    }

    /// Session-lifespan resources must survive the process scoping, since resources added through the
    /// metadata handler default to that lifespan.
    func test_getResource_keepsSessionAndPermanentResources() {
        storage.addMetadata(
            key: "session-scoped",
            value: "value",
            type: .resource,
            lifespan: .session,
            lifespanId: "some-session"
        )
        storage.addMetadata(
            key: "permanent-scoped",
            value: "value",
            type: .resource,
            lifespan: .permanent,
            lifespanId: MetadataRecord.lifespanIdForPermanent
        )

        let attributes = ResourceStorageExporter(storage: storage).getResource().attributes

        XCTAssertEqual(attributes["session-scoped"]?.description, "value")
        XCTAssertEqual(attributes["permanent-scoped"]?.description, "value")
    }
}
