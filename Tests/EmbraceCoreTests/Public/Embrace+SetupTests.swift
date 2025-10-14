//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore

class EmbraceSetupTests: XCTestCase {
    func test_setupOnNonMainThread_shouldThrowInvalidThreadError() {
        let expectation = expectation(description: testName)
        DispatchQueue(label: "myThread").async {
            do {
                try Embrace.setup(
                    options: .init(
                        appId: "-----",
                        captureServices: [],
                        crashReporter: nil
                    )
                )
                XCTFail("This should've thrown an error")
                expectation.fulfill()
            } catch let exception {
                if case .invalidThread(_) = exception as? EmbraceSetupError {
                    // The description isn’t important; what matters is that the case is correct
                    XCTAssertTrue(true)
                } else {
                    XCTFail("Wrong EmbraceSetupError was thrown \(exception)")
                }
                expectation.fulfill()
            }
        }
        wait(for: [expectation])
    }
}
