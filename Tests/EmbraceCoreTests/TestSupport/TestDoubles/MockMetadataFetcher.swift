//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
import XCTest
@testable import EmbraceCore
@testable import EmbraceStorage
import EmbraceCommon

class MockMetadataFetcher: EmbraceStorageMetadataFetcher {
    var resources: [MetadataRecord]?

    init(resources: [MetadataRecord]? = nil) {
        self.resources = resources
    }

    func fetchAllResources() throws -> [MetadataRecord] {
        return resources ?? []
    }

    func fetchResourcesForSessionId(_ sessionId: SessionIdentifier) throws -> [MetadataRecord] {
        return resources ?? []
    }

    func fetchAllCustomProperties() throws -> [MetadataRecord] {
        return resources ?? []
    }

    func fetchCustomPropertiesForSessionId(_ sessionId: SessionIdentifier) throws -> [MetadataRecord] {
        return resources ?? []
    }
}
