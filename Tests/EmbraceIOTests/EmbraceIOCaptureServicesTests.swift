//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCaptureService
import EmbraceCommonInternal
import EmbraceConfiguration
import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceIO

final class EmbraceIOCaptureServicesTests: XCTestCase {

    override func setUpWithError() throws {
        Embrace.client = nil
        EmbraceIO.shared.otelBridge.safeValue = nil
    }

    override func tearDownWithError() throws {
        _ = try? Embrace.client?.stop()
        Embrace.client = nil
        EmbraceIO.shared.otelBridge.safeValue = nil
    }

    private var options: EmbraceIO.Options {
        EmbraceIO.Options.withLocalConfiguration(
            captureServices: CaptureServicesOptionsBuilder().build(),
            crashReporter: .none,
            otel: EmbraceIO.OTelOptions()
        )
    }

    // MARK: Adding capture services

    func test_addCaptureService_afterStart_installsAndStartsIt() throws {
        // given a started SDK with an active session
        try EmbraceIO.start(options: options)
        XCTAssertNotNil(Embrace.client?.sessionController.currentSession)

        // when adding a capture service
        let service = LateCaptureService()
        EmbraceIO.shared.add(captureService: service)

        // then the service receives the current config, is installed, started and notified of the current session
        XCTAssertNotNil(service.receivedConfig)
        XCTAssertTrue(service.isActive)
        XCTAssertEqual(service.installCount, 1)
        XCTAssertEqual(service.startCount, 1)
        XCTAssertEqual(service.sessionStartCount, 1)
        XCTAssertTrue(Embrace.client?.captureServices.services.contains { $0 === service } == true)
    }

    func test_addCaptureService_beforeStart_isInstalledOnStart() throws {
        // given a SDK that was setup but not started
        let internalOptions = try XCTUnwrap(Embrace.Options.from(options: options))
        let client = try Embrace.setup(options: internalOptions)

        // when adding a capture service
        let service = LateCaptureService()
        client.add(captureService: service)

        // then it's not installed yet
        XCTAssertTrue(service.isUninstalled)

        // when the SDK starts
        try client.start()

        // then the service is installed and started once
        XCTAssertTrue(service.isActive)
        XCTAssertEqual(service.installCount, 1)
        XCTAssertEqual(service.startCount, 1)
    }

    func test_addCaptureService_duplicateType_isIgnored() throws {
        // given a started SDK with a capture service added
        try EmbraceIO.start(options: options)
        EmbraceIO.shared.add(captureService: LateCaptureService())

        // when adding another capture service of the same type
        let duplicate = LateCaptureService()
        EmbraceIO.shared.add(captureService: duplicate)

        // then it's ignored
        XCTAssertTrue(duplicate.isUninstalled)
        XCTAssertEqual(duplicate.installCount, 0)
    }

    func test_addCaptureService_afterStop_isIgnored() throws {
        // given a stopped SDK
        try EmbraceIO.start(options: options)
        try EmbraceIO.shared.stop()

        // when adding a capture service
        let service = LateCaptureService()
        EmbraceIO.shared.add(captureService: service)

        // then it's ignored
        XCTAssertTrue(service.isUninstalled)
        XCTAssertFalse(Embrace.client?.captureServices.services.contains { $0 === service } == true)
    }

    func test_addCaptureService_concurrentStop_stopsTheService() throws {
        // given a started SDK
        try EmbraceIO.start(options: options)

        // and a capture service that pauses while it's being added
        let service = LateCaptureService()
        let addingStarted = DispatchSemaphore(value: 0)
        let resumeAdding = DispatchSemaphore(value: 0)
        service.onConfigUpdatedHook = {
            addingStarted.signal()
            // gives `stop()` the chance to run while the service is being added
            _ = resumeAdding.wait(timeout: .now() + 0.5)
        }

        // when the SDK is stopped while the capture service is being added
        let added = expectation(description: "capture service added")
        DispatchQueue.global().async {
            EmbraceIO.shared.add(captureService: service)
            added.fulfill()
        }
        addingStarted.wait()
        try EmbraceIO.shared.stop()
        resumeAdding.signal()
        wait(for: [added], timeout: .defaultTimeout)

        // then the capture service is not left running
        XCTAssertFalse(service.isActive)
    }

    func test_addCaptureService_sessionNotificationWhileAdding_isOnlyDeliveredAfterInstall() throws {
        // given a started SDK with an active session
        try EmbraceIO.start(options: options)
        let session = try XCTUnwrap(Embrace.client?.sessionController.currentSession)

        // when the session start notification arrives while a capture service is being added
        let service = LateCaptureService()
        service.onConfigUpdatedHook = {
            NotificationCenter.default.post(name: .embraceSessionPartDidStart, object: session)
        }
        EmbraceIO.shared.add(captureService: service)

        // then the capture service is only notified once, after being installed
        XCTAssertFalse(service.sessionStartedBeforeInstall)
        XCTAssertEqual(service.sessionStartCount, 1)
    }

    func test_addCaptureService_sessionNotificationAfterAdding_isOnlyDeliveredForNewSessions() throws {
        // given a started SDK with an active session
        // and a capture service added afterwards
        try EmbraceIO.start(options: options)
        let session = try XCTUnwrap(Embrace.client?.sessionController.currentSession)
        let service = LateCaptureService()
        EmbraceIO.shared.add(captureService: service)
        XCTAssertEqual(service.sessionStartCount, 1)

        // when the notification of the same session arrives
        NotificationCenter.default.post(name: .embraceSessionPartDidStart, object: session)

        // then the capture service is not notified again
        XCTAssertEqual(service.sessionStartCount, 1)

        // when a new session starts
        let newSession = MockSession(
            id: .random,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )
        NotificationCenter.default.post(name: .embraceSessionPartDidStart, object: newSession)

        // then the capture service is notified
        XCTAssertEqual(service.sessionStartCount, 2)
    }

    // MARK: Resources

    func test_addResources_storesResourcesForCurrentProcess() throws {
        // given a started SDK
        try EmbraceIO.start(options: options)
        let client = try XCTUnwrap(Embrace.client)

        // when adding resources
        EmbraceIO.shared.addResources(["test.resource.1": "value1", "test.resource.2": "value2"])
        client.metadata.synchronizationQueue.sync {}

        // then they are stored for the current process
        let resources = client.storage.fetchResourcesForProcessId(ProcessIdentifier.current)
        XCTAssertEqual(resources.first { $0.key == "test.resource.1" }?.value, "value1")
        XCTAssertEqual(resources.first { $0.key == "test.resource.2" }?.value, "value2")
        XCTAssertEqual(resources.first { $0.key == "test.resource.1" }?.type, .resource)
    }

    func test_addResources_respectsResourcesLimit() throws {
        // given a started SDK
        try EmbraceIO.start(options: options)
        let client = try XCTUnwrap(Embrace.client)
        let limit = client.storage.options.resourcesLimit

        // when adding more resources than the limit allows
        var resources: [String: String] = [:]
        for index in 0..<(limit + 10) {
            resources["test.limit.\(index)"] = "value"
        }
        EmbraceIO.shared.addResources(resources)
        client.metadata.synchronizationQueue.sync {}

        // then the resources over the limit are dropped
        let stored = client.storage.fetchResourcesForProcessId(ProcessIdentifier.current).filter { $0.key.hasPrefix("test.limit.") }
        XCTAssertLessThanOrEqual(stored.count, limit)
    }

    func test_addResources_overwritesExistingKeys() throws {
        // given a started SDK with a resource added
        try EmbraceIO.start(options: options)
        let client = try XCTUnwrap(Embrace.client)
        EmbraceIO.shared.addResources(["test.resource": "old"])

        // when adding a resource with the same key
        EmbraceIO.shared.addResources(["test.resource": "new"])
        client.metadata.synchronizationQueue.sync {}

        // then the value is overwritten
        let resources = client.storage.fetchResourcesForProcessId(ProcessIdentifier.current).filter { $0.key == "test.resource" }
        XCTAssertEqual(resources.count, 1)
        XCTAssertEqual(resources.first?.value, "new")
    }

    func test_addResources_reservedKeys_areNotOverwritten() throws {
        // given a started SDK with the SDK's resources stored
        try EmbraceIO.start(options: options)
        let client = try XCTUnwrap(Embrace.client)
        let sdkVersionKey = AppResourceKey.sdkVersion.rawValue
        let osVersionKey = DeviceResourceKey.osVersion.rawValue
        let stored = expectation(description: "resources stored")
        client.storage.coreData.performAsyncOperation { _ in stored.fulfill() }
        wait(for: [stored], timeout: 5)

        // when adding resources with reserved keys
        EmbraceIO.shared.addResources([sdkVersionKey: "fake", osVersionKey: "fake", "test.resource.allowed": "value"])
        client.metadata.synchronizationQueue.sync {}

        // then the reserved resources are dropped and the SDK values are kept
        let resources = client.storage.fetchResourcesForProcessId(ProcessIdentifier.current)
        XCTAssertFalse(resources.contains { $0.key == sdkVersionKey && $0.value == "fake" })
        XCTAssertFalse(resources.contains { $0.key == osVersionKey && $0.value == "fake" })
        XCTAssertEqual(resources.filter { $0.key == sdkVersionKey }.map(\.value), [EmbraceMeta.sdkVersion])
        XCTAssertEqual(resources.first { $0.key == "test.resource.allowed" }?.value, "value")
    }

    func test_startResources_reservedKeys_areNotOverwritten() throws {
        // given a SDK started with resources that use reserved keys
        let sdkVersionKey = AppResourceKey.sdkVersion.rawValue
        let internalOptions = try XCTUnwrap(Embrace.Options.from(options: options))
        let client = try Embrace.setup(
            options: internalOptions,
            otelResources: [sdkVersionKey: "fake", "test.start.allowed": "value"]
        )
        try client.start()

        // when the start resources are stored
        client.processingQueue.sync {}
        client.metadata.synchronizationQueue.sync {}
        let stored = expectation(description: "resources stored")
        client.storage.coreData.performAsyncOperation { _ in stored.fulfill() }
        wait(for: [stored], timeout: 5)

        // then the reserved resources are dropped and the SDK values are kept
        let resources = client.storage.fetchResourcesForProcessId(ProcessIdentifier.current)
        XCTAssertEqual(resources.filter { $0.key == sdkVersionKey }.map(\.value), [EmbraceMeta.sdkVersion])
        XCTAssertEqual(resources.first { $0.key == "test.start.allowed" }?.value, "value")
    }

    func test_addResources_whenNotStarted_isIgnored() throws {
        // given a SDK that was setup but not started
        let internalOptions = try XCTUnwrap(Embrace.Options.from(options: options))
        let client = try Embrace.setup(options: internalOptions)

        // when adding resources
        client.addResources(["test.resource.not_started": "value"])
        client.metadata.synchronizationQueue.sync {}

        // then nothing is stored
        let resources = client.storage.fetchResourcesForProcessId(ProcessIdentifier.current)
        XCTAssertNil(resources.first { $0.key == "test.resource.not_started" })
    }
}

private class LateCaptureService: CaptureService {
    var installCount = 0
    var startCount = 0
    var sessionStartCount = 0
    var sessionStartedBeforeInstall = false
    var receivedConfig: EmbraceConfigurable?

    /// Called once, the first time the capture service receives a config.
    var onConfigUpdatedHook: (() -> Void)?

    override func onInstall() { installCount += 1 }
    override func onStart() { startCount += 1 }

    override func onConfigUpdated(_ config: EmbraceConfigurable) {
        receivedConfig = config
        let hook = onConfigUpdatedHook
        onConfigUpdatedHook = nil
        hook?()
    }

    override func onSessionStart() {
        if isUninstalled {
            sessionStartedBeforeInstall = true
        }
        sessionStartCount += 1
    }
}
