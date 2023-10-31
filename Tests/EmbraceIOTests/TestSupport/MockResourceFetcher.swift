//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
import XCTest
@testable import EmbraceIO
@testable import EmbraceStorage

class MockResourceFetcher: EmbraceStorageResourceFetcher {
    var resources: [ResourceRecord]?

    init(resources: [ResourceRecord]? = nil) {
        self.resources = resources
    }

    func fetchAllResourceForSession(sessionId: String) throws -> [ResourceRecord]? {
        return resources
    }

    func fetchAllResources() throws -> [ResourceRecord]? {
        return resources
    }
}
