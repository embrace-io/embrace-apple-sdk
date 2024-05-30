//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
import XCTest
@testable import EmbraceCore
@testable import EmbraceStorage
import EmbraceCommon

class MockMetadataFetcher: EmbraceStorageMetadataFetcher {
    var metadata: [MetadataRecord]

    init(metadata: [MetadataRecord] = []) {
        self.metadata = metadata
    }

    func fetchAllResources() throws -> [MetadataRecord] {
        return metadata
    }

    func fetchResourcesForSessionId(_ sessionId: SessionIdentifier) throws -> [MetadataRecord] {
        return metadata.filter { record in
            (record.type == .resource || record.type == .requiredResource)
        }
    }

    func fetchResourcesForProcessId(_ processId: ProcessIdentifier) throws -> [MetadataRecord] {
        return metadata.filter { record in
            (record.type == .resource || record.type == .requiredResource) &&
            record.lifespan == .process &&
            record.lifespanId == processId.hex
        }
    }

    func fetchAllCustomProperties() throws -> [MetadataRecord] {
        return metadata.filter { $0.type == .customProperty }
    }

    func fetchCustomPropertiesForSessionId(_ sessionId: SessionIdentifier) throws -> [MetadataRecord] {
        return metadata.filter { record in
            record.type == .customProperty &&
            record.lifespan == .session &&
            record.lifespanId == sessionId.toString
        }
    }
}
