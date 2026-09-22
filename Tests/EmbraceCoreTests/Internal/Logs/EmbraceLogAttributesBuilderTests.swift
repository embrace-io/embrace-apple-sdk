//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

class EmbraceLogAttributesBuilderTests: XCTestCase {
    private var sut: EmbraceLogAttributesBuilder!
    private var storage: MockMetadataFetcher!
    private var controller: MockSessionController!
    private var result: EmbraceAttributes!

    // MARK: - Test Build Alone

    func testNotCallingOtherMethod_build_returnsInitialAttributes() {
        givenSessionController()
        givenMetadataFetcher()
        givenEmbraceLogAttributesBuilder(withInitialAttributes: ["hello": "world"])
        whenInvokingBuild()
        thenResultingAttributes(is: ["hello": "world"])
    }

    // MARK: - addSessionIdentifier Tests

    func testOnHavingSession_addSessionIdentifier_addsTheIdentifierToAttributes() {
        let identifier = EmbraceIdentifier.random
        let userSessionId = EmbraceIdentifier.random
        givenSessionController(sessionWithId: identifier, userSessionId: userSessionId)
        givenMetadataFetcher()
        givenEmbraceLogAttributesBuilder()

        whenInvokingAddSessionIdentifier()
        whenInvokingBuild()

        // `session.id` carries the user-session UUID in v7; `emb.session_part_id` carries the
        // part UUID. All three identity keys are always present.
        thenResultingAttributes(is: [
            "session.id": userSessionId.stringValue,
            "emb.user_session_id": userSessionId.stringValue,
            "emb.session_part_id": identifier.stringValue
        ])
    }

    func testOnNotHavingSession_addSessionIdentifier_addsEmptyStringsToAttributes() {
        givenSessionControllerWithNoSession()
        givenMetadataFetcher()
        givenEmbraceLogAttributesBuilder()

        whenInvokingAddSessionIdentifier()
        whenInvokingBuild()

        // Spec requires the three keys be present even as empty strings when no session is active.
        thenResultingAttributes(is: [
            "session.id": "",
            "emb.user_session_id": "",
            "emb.session_part_id": ""
        ])
    }

    // MARK: - addApplicationProperties Tests

    func testOnHavingMetadataCustomProperties_addApplicationProperties_addsCustomPropertiesToAttributes() {
        let userSessionId = EmbraceIdentifier.random
        givenSessionController(userSessionId: userSessionId)
        givenMetadataFetcher(with: [
            MockMetadata.createSessionPropertyRecord(
                key: "custom_prop_int", value: "1", userSessionId: userSessionId),
            MockMetadata.createSessionPropertyRecord(
                key: "custom_prop_bool", value: "false", userSessionId: userSessionId),
            MockMetadata.createSessionPropertyRecord(
                key: "custom_prop_double", value: "3.0", userSessionId: userSessionId),
            MockMetadata.createSessionPropertyRecord(
                key: "custom_prop_string", value: "hello", userSessionId: userSessionId)
        ]
        )
        givenEmbraceLogAttributesBuilder()

        whenInvokingAddApplicationProperties()
        whenInvokingBuild()

        thenResultingAttributes(is: [
            "emb.properties.custom_prop_int": "1",
            "emb.properties.custom_prop_bool": "false",
            "emb.properties.custom_prop_double": "3.0",
            "emb.properties.custom_prop_string": "hello"
        ])
    }

    func testOnNotHavingCustomProperties_addApplicationProperties_addsNothingToAttributes() {
        givenSessionController()
        givenMetadataFetcher(with: nil)
        givenEmbraceLogAttributesBuilder()

        whenInvokingAddApplicationProperties()
        whenInvokingBuild()

        thenResultingAttributes(is: .empty())
    }

    func testOnNotHavingSession_addApplicationProperties_addsNothingToAttributes() {
        givenSessionControllerWithNoSession()
        // Shouldnt happen to have custom user session properties with no session, but just in case :)
        givenMetadataFetcher(with: [
            MockMetadata.createSessionPropertyRecord(key: "custom_prop_string", value: "hello")
        ])
        givenEmbraceLogAttributesBuilder()

        whenInvokingAddApplicationProperties()
        whenInvokingBuild()

        thenResultingAttributes(is: .empty())
    }

    func testOnNewSessionPartOfSameUserSession_addApplicationProperties_stillAddsCustomProperties() {
        let userSessionId = EmbraceIdentifier.random

        // given properties of a user session, added during a previous part
        givenSessionController(sessionWithId: .random, userSessionId: userSessionId)
        givenMetadataFetcher(with: [
            MockMetadata.createSessionPropertyRecord(
                key: "custom_prop_string", value: "hello", userSessionId: userSessionId)
        ])
        givenEmbraceLogAttributesBuilder()

        // when a log is built during a brand-new part of the same user session
        controller.currentSession = MockSession.with(
            id: .random,
            state: .background,
            userSessionId: userSessionId
        )

        whenInvokingAddApplicationProperties()
        whenInvokingBuild()

        // then the properties are still there
        thenResultingAttributes(is: ["emb.properties.custom_prop_string": "hello"])
    }

    func testOnNewUserSession_addApplicationProperties_addsNothingToAttributes() {
        // given properties of a user session that already ended
        givenSessionController()
        givenMetadataFetcher(with: [
            MockMetadata.createSessionPropertyRecord(
                key: "custom_prop_string", value: "hello", userSessionId: .random)
        ])
        givenEmbraceLogAttributesBuilder()

        whenInvokingAddApplicationProperties()
        whenInvokingBuild()

        // then they don't apply to the current user session
        thenResultingAttributes(is: .empty())
    }

    // MARK: - addApplicationState Tests

    func testOnHavingSession_addApplicationState_addsSessionsCurrentStateToAttributes() throws {
        let randomSessionState: SessionState = try XCTUnwrap([.background, .foreground].randomElement())
        givenSessionController(sessionState: randomSessionState)
        givenMetadataFetcher()
        givenEmbraceLogAttributesBuilder()

        whenInvokingAddApplicationState()
        whenInvokingBuild()

        thenResultingAttributes(is: ["emb.state": randomSessionState.rawValue])
    }

    func testOnNotHavingSession_addApplicationState_addsNothingToAttributes() {
        givenSessionControllerWithNoSession()
        givenMetadataFetcher()
        givenEmbraceLogAttributesBuilder()

        whenInvokingAddApplicationState()
        whenInvokingBuild()

        thenResultingAttributes(is: .empty())
    }

    // MARK: - addStackTrace Tests

    func testOnProvidingEmptyArrayOfStackTrace_onAddStackTrace_doesNothing() {
        givenSessionController()
        givenMetadataFetcher()
        givenEmbraceLogAttributesBuilder()

        sut.addStackTrace([])
        whenInvokingBuild()

        thenResultingAttributes(is: .empty())
    }

    func test_onAddStackTrace_doesNothing() {
        givenSessionController()
        givenMetadataFetcher()
        givenEmbraceLogAttributesBuilder()

        sut.addStackTrace(Thread.callStackSymbols)
        whenInvokingBuild()

        thenResultingAttributes(containsKey: "emb.stacktrace.ios")
    }

    // MARK: - addBackTrace Tests

    func test_addBacktrace_addsStacktraceAttribute() {
        givenSessionController()
        givenMetadataFetcher()
        givenEmbraceLogAttributesBuilder()

        // A canned single-thread backtrace: `addBacktrace` only needs a non-empty thread list, so
        // this avoids depending on a configured backtracer to capture one.
        let thread = EmbraceBacktraceThread(index: 0, callstack: .init(addresses: [0x1], count: 1))
        let backtrace = EmbraceBacktrace(timestampUnits: .nanoseconds, timestamp: 0, threads: [thread])
        sut.addBacktrace(backtrace)
        whenInvokingBuild()

        thenResultingAttributes(containsKey: "emb.stacktrace.ios")
    }

    // MARK: - addLogType Tests
    func test_onAddLogType_addsValue() {
        givenSessionController()
        givenMetadataFetcher()
        givenEmbraceLogAttributesBuilder()

        whenInvokingAddLogType(.message)
        whenInvokingBuild()

        thenResultingAttributes(is: ["emb.type": EmbraceType.message.rawValue])
    }
}

extension EmbraceLogAttributesBuilderTests {
    fileprivate func givenSessionController(
        sessionWithId sessionId: EmbraceIdentifier = .random,
        userSessionId: EmbraceIdentifier = .random,
        processId: EmbraceIdentifier = .random,
        sessionState: SessionState = .foreground
    ) {
        controller = MockSessionController()
        controller.currentSession = MockSession.with(
            id: sessionId,
            state: sessionState,
            processId: processId,
            userSessionId: userSessionId
        )
    }

    fileprivate func givenSessionControllerWithNoSession() {
        controller = MockSessionController()
    }

    fileprivate func givenMetadataFetcher(with metadata: [EmbraceMetadata]? = nil) {
        storage = .init(metadata: metadata ?? [])
    }

    fileprivate func givenEmbraceLogAttributesBuilder(withInitialAttributes attributes: [String: String] = [:]) {
        sut = .init(
            storage: storage,
            sessionControllable: controller,
            initialAttributes: attributes
        )
    }

    fileprivate func whenInvokingBuild() {
        result = sut.build()
    }

    fileprivate func whenInvokingAddSessionIdentifier() {
        sut.addSessionIdentifier()
    }

    fileprivate func whenInvokingAddApplicationProperties() {
        sut.addApplicationProperties()
    }

    fileprivate func whenInvokingAddApplicationState() {
        sut.addApplicationState()
    }

    fileprivate func whenInvokingAddLogType(_ logType: EmbraceType) {
        sut.addLogType(logType)
    }

    fileprivate func thenResultingAttributes(is dict: EmbraceAttributes) {
        XCTAssertEqual(result.count, dict.count)
        for key in result.keys {
            XCTAssertEqual("\(result[key]!)", "\(dict[key]!)")
        }
    }

    fileprivate func thenResultingAttributes(containsKey key: String) {
        XCTAssertNotNil(result[key])
    }
}
