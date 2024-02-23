//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import EmbraceStorage
import EmbraceCommon

@testable import EmbraceCore

class EmbraceLogAttributesBuilderTests: XCTestCase {
    private var sut: EmbraceLogAttributesBuilder!
    private var storage: MockMetadataFetcher!
    private var controller: SpySessionController!
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
        let identifier = UUID()
        givenSessionController(sessionWithId: identifier)
        givenMetadataFetcher()
        givenEmbraceLogAttributesBuilder()

        whenInvokingAddSessionIdentifier()
        whenInvokingBuild()

        thenResultingAttributes(is: ["emb.session_id": identifier.uuidString])
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
        givenSessionController()
        givenMetadataFetcher(with: [
            .createSessionPropertyRecord(key: "custom_prop_int", value: .int(1)),
            .createSessionPropertyRecord(key: "custom_prop_bool", value: .bool(false)),
            .createSessionPropertyRecord(key: "custom_prop_double", value: .double(3.0)),
            .createSessionPropertyRecord(key: "custom_prop_string", value: .string("hello"))]
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
            .createSessionPropertyRecord(key: "custom_prop_string", value: .string("hello"))
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

        whenInvokingAddStackTrace(withStack: [])
        whenInvokingBuild()

        thenResultingAttributes(is: .empty())
    }

    func test_onAddStackTrace_doesNothing() {
        givenSessionController()
        givenMetadataFetcher()
        givenEmbraceLogAttributesBuilder()

        whenInvokingAddStackTrace(withStack: Thread.callStackSymbols)
        whenInvokingBuild()

        thenResultingAttributes(containsKey: "emb.stacktrace.ios")
    }
}

private extension EmbraceLogAttributesBuilderTests {
    func givenSessionController(
        sessionWithId sessionId: UUID = .init(),
        sessionState: SessionState = .foreground
    ) {
        controller = SpySessionController(currentSession: .with(id: sessionId, state: sessionState))
    }

    func givenSessionControllerWithNoSession() {
        controller = SpySessionController(currentSession: nil)
    }

    func givenMetadataFetcher(with metadata: [MetadataRecord]? = nil) {
        storage = .init(resources: metadata)
    }

    func givenEmbraceLogAttributesBuilder(withInitialAttributes attributes: [String: String] = [:]) {
        sut = .init(
            storage: storage,
            sessionControllable: controller,
            initialAttributes: attributes
        )
    }

    func whenInvokingBuild() {
        result = sut.build()
    }

    func whenInvokingAddStackTrace(withStack stacktrace: [String]) {
        sut.addStackTrace(stacktrace)
    }

    func whenInvokingAddSessionIdentifier() {
        sut.addSessionIdentifier()
    }

    func whenInvokingAddApplicationProperties() {
        sut.addApplicationProperties()
    }

    func whenInvokingAddApplicationState() {
        sut.addApplicationState()
    }

    func thenResultingAttributes(is dict: [String: String]) {
        XCTAssertEqual(result, dict)
    }

    func thenResultingAttributes(containsKey key: String) {
        XCTAssertNotNil(result[key])
    }
}
