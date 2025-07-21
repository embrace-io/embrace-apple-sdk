//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore

final class EmbraceEndpointsTests: XCTestCase {
    func test_urls() throws {
        // given a default Embrace.Endpoints
        let endpoints = Embrace.Endpoints(appId: "appId")

        // then the URLs have the correct domains
        XCTAssert(endpoints.baseURL.contains("a-appId"))
        XCTAssert(endpoints.configBaseURL.contains("a-appId"))
    }
}
