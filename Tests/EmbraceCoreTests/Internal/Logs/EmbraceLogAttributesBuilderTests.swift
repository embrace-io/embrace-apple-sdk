//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

class EmbraceLogAttributesBuilderTests: XCTestCase {
    private var sut: EmbraceLogAttributesBuilder!
    private var storage: MockMetadataFetcher!
    private var controller: MockSessionController!
    private var result: [String: String]!

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
        let identifier = SessionIdentifier.random
        givenSessionController(sessionWithId: identifier)
        givenMetadataFetcher()
        givenEmbraceLogAttributesBuilder()

        whenInvokingAddSessionIdentifier()
        whenInvokingBuild()

        thenResultingAttributes(is: ["session.id": identifier.toString])
    }

    func testOnNotHavingSession_addSessionIdentifier_addsNothingToAttributes() {
        givenSessionControllerWithNoSession()
        givenMetadataFetcher()
        givenEmbraceLogAttributesBuilder()

        whenInvokingAddSessionIdentifier()
        whenInvokingBuild()

        thenResultingAttributes(is: .empty())
    }

    // MARK: - addApplicationProperties Tests

    func testOnHavingMetadataCustomProperties_addApplicationProperties_addsCustomPropertiesToAttributes() {
        let sessionId = SessionIdentifier.random
        givenSessionController(sessionWithId: sessionId)
        givenMetadataFetcher(with: [
            MockMetadata.createSessionPropertyRecord(key: "custom_prop_int", value: .int(1), sessionId: sessionId),
            MockMetadata.createSessionPropertyRecord(
                key: "custom_prop_bool", value: .bool(false), sessionId: sessionId),
            MockMetadata.createSessionPropertyRecord(
                key: "custom_prop_double", value: .double(3.0), sessionId: sessionId),
            MockMetadata.createSessionPropertyRecord(
                key: "custom_prop_string", value: .string("hello"), sessionId: sessionId)
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
        // Shouldnt happen to have custom session properties with no session, but just in case :)
        givenMetadataFetcher(with: [
            MockMetadata.createSessionPropertyRecord(key: "custom_prop_string", value: .string("hello"))
        ])
        givenEmbraceLogAttributesBuilder()

        whenInvokingAddApplicationProperties()
        whenInvokingBuild()

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

    func test_onAddBacktrace_doesNothing() {
        givenSessionController()
        givenMetadataFetcher()
        givenEmbraceLogAttributesBuilder()

        sut.addBacktrace(EmbraceBacktrace.backtrace())
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

        thenResultingAttributes(is: ["emb.type": LogType.message.rawValue])
    }

    func test_onAddLogType_whenAlreadySet_doesNotChangeValue() {
        givenSessionController()
        givenMetadataFetcher()
        givenEmbraceLogAttributesBuilder(withInitialAttributes: ["emb.type": LogType.crash.rawValue])

        whenInvokingAddLogType(.message)
        whenInvokingBuild()

        thenResultingAttributes(is: ["emb.type": LogType.crash.rawValue])
    }

}

extension EmbraceLogAttributesBuilderTests {
    fileprivate func givenSessionController(
        sessionWithId sessionId: SessionIdentifier = .random,
        sessionState: SessionState = .foreground
    ) {
        controller = MockSessionController()
        controller.currentSession = MockSession.with(id: sessionId, state: sessionState)
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

    fileprivate func whenInvokingAddLogType(_ logType: LogType) {
        sut.addLogType(logType)
    }

    fileprivate func thenResultingAttributes(is dict: [String: String]) {
        XCTAssertEqual(result, dict)
    }

    fileprivate func thenResultingAttributes(containsKey key: String) {
        XCTAssertNotNil(result[key])
    }
}
