//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore

/// This test case class should be used for any tests where you are
/// calling 'Embrace.setup'.
/// This class will handle the setup and teardown
open class IntegrationTestCase: XCTestCase {

    override open func setUpWithError() throws {
        EmbraceHTTPMock.setUp()

        if let baseURL = EmbraceFileSystem.rootURL() {
            try? FileManager.default.removeItem(at: baseURL)
        }
    }

    override open func tearDownWithError() throws {
        Embrace.client = nil
        if let baseURL = EmbraceFileSystem.rootURL() {
            try? FileManager.default.removeItem(at: baseURL)
        }
        EmbraceHTTPMock.tearDown()
    }

}
