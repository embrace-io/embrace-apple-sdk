//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
import XCTest
@testable import EmbraceCore
@testable import EmbraceStorage
import EmbraceCommon

class MockResourceFetcher: EmbraceStorageResourceFetcher {
    var resources: [ResourceRecord]?

    init(resources: [ResourceRecord]? = nil) {
        self.resources = resources
    }

    func fetchAllResourceForSession(sessionId: SessionIdentifier) throws -> [ResourceRecord]? {
        return resources
    }

    func fetchAllResources() throws -> [ResourceRecord]? {
        return resources
    }
}
