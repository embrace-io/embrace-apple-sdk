//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
import EmbraceCommon

final class EmbraceIOTests: XCTestCase {

    // this is used in the helper function
    private let lock: UnfairLock = UnfairLock()

    func test_ConcurrentCurrentSessionId() throws {
        let embrace = try getLocalEmbrace()
        try embrace?.start()
        let sessionId = embrace?.currentSessionId()

        // concurrentPerform performs concurrent operations in a synchronous manner on the called thread.
        // so it seems to be good for testing as it prevents the requried
        // use of expectations
        DispatchQueue.concurrentPerform(iterations: 100) {_ in
            let cSessionId = embrace?.currentSessionId()
            XCTAssertEqual(cSessionId, sessionId)
        }

    }

    func test_ConcurrentCurrentSessionIdWhileEndingSession() throws {
        let embrace = try getLocalEmbrace()
        try embrace?.start()

        // concurrentPerform performs concurrent operations in a synchronous manner on the called thread.
        // so it seems to be good for testing as it prevents the requried
        // use of expectations
        DispatchQueue.concurrentPerform(iterations: 100) {_ in
            let id = embrace?.currentSessionId()
            embrace?.endCurrentSession()
            XCTAssertNotNil(id)
        }
    }

    func test_ConcurrentCurrentSessionIdWhileStartingSession() throws {
        let embrace = try getLocalEmbrace()
        try embrace?.start()
        // concurrentPerform performs concurrent operations in a synchronous manner on the called thread.
        // so it seems to be good for testing as it prevents the requried
        // use of expectations
        DispatchQueue.concurrentPerform(iterations: 100) {_ in
            let id = embrace?.currentSessionId()
            embrace?.startNewSession()
            XCTAssertNotNil(id)
        }
    }

    func test_CuncurrentEndSession() throws {
        let embrace = try getLocalEmbrace()
        try embrace?.start()
        let sessionId = embrace?.currentSessionId()

        // concurrentPerform performs concurrent operations in a synchronous manner on the called thread.
        // so it seems to be good for testing as it prevents the requried
        // use of expectations
        DispatchQueue.concurrentPerform(iterations: 100) {_ in
            embrace?.endCurrentSession()
            let cSessionId = embrace?.currentSessionId()
            XCTAssertNotEqual(cSessionId, sessionId)
        }

        // added this for the non ios lifecycle case
        embrace?.startNewSession()
        let cSessionId = embrace?.currentSessionId()
        XCTAssertNotEqual(cSessionId, sessionId)
    }

    func test_CuncurrentStartSession() throws {
        let embrace = try getLocalEmbrace()
        try embrace?.start()
        let sessionId = embrace?.currentSessionId()

        // concurrentPerform performs concurrent operations in a synchronous manner on the called thread.
        // so it seems to be good for testing as it prevents the requried
        // use of expectations
        DispatchQueue.concurrentPerform(iterations: 100) {_ in
            embrace?.startNewSession()
            let cSessionId = embrace?.currentSessionId()
            XCTAssertNotEqual(cSessionId, sessionId)
        }
    }

    func test_EmbraceStartNonMainThreadShouldThrow() throws {
        let embrace = try getLocalEmbrace()
        let expectation = self.expectation(description: "testWillNotDeadlock")

        DispatchQueue.global().async {
            // with the do / catch we get a warning but without it there is an error.
            // Not sure the correct thing to do here but this works at least for now

            do {
                XCTAssertThrowsError(try embrace?.start()) { error in
                    XCTAssertEqual(
                        error as? EmbraceSetupError,
                        EmbraceSetupError.invalidThread("Embrace must be started on the main thread")
                    )
                }
            } catch let e {
                XCTFail("unexpected exception \(e.localizedDescription)")
            }

            expectation.fulfill()
        }

        waitForExpectations(timeout: 100)
    }

    func test_EmbraceStartOnMainThreadShouldNotThrow() throws {
        guard let embrace = try getLocalEmbrace() else {
            XCTFail("failed to get embrace instance")
            return
        }

        try embrace.start()

        XCTAssertTrue(embrace.started)
    }

    // MARK: - Helper Methods
    func getLocalEmbrace()throws -> Embrace? {
        // to ensure that each test gets it's own instance of embrace.
        return try lock.locked {
            // I use random string for group id to ensure a different storage location each time
            try Embrace.setup(options: .init(appId: "testA", appGroupId: randomString(length: 5), captureServices: []))
            XCTAssertNotNil(Embrace.client)
            let embrace = Embrace.client
            Embrace.client = nil
            return embrace
        }
    }

    func randomString(length: Int) -> String {
      let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      return String((0..<length).map { _ in letters.randomElement()! })
    }
}
