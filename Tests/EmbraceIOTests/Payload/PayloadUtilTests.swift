//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceIO
@testable import EmbraceStorage
@testable import EmbraceCommon

final class PayloadUtilTests: XCTestCase {
    func test_fetchResources() throws {
        // given
        let mockResources: [ResourceRecord] = [.init(key: "fake_res", value: "fake_value", resourceType: .process)]
        let fetcher = MockResourceFetcher(resources: mockResources)

        // when
        let fetchedResources = PayloadUtils.fetchResources(from: fetcher, sessionId: "fake_session")

        // then the session payload contains the necessary keys
        XCTAssertEqual(mockResources, fetchedResources)
    }
}
