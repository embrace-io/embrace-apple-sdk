//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
import XCTest
@testable import EmbraceCore
@testable import EmbraceStorageInternal
import EmbraceCommonInternal

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

    func fetchCustomPropertiesForSessionId(_ sessionId: SessionIdentifier) throws -> [MetadataRecord] {
        return metadata.filter { record in
            record.type == .customProperty &&
            record.lifespan == .session &&
            record.lifespanId == sessionId.toString
        }
    }

    func fetchPersonaTagsForSessionId(_ sessionId: SessionIdentifier) throws -> [MetadataRecord] {
        return metadata.filter { record in
            record.type == .personaTag &&
            record.lifespan == .session &&
            record.lifespanId == sessionId.toString
        }
    }

    func fetchPersonaTagsForProcessId(_ processId: ProcessIdentifier) throws -> [MetadataRecord] {
        return metadata.filter { record in
            record.type == .personaTag &&
            record.lifespan == .process &&
            record.lifespanId == processId.hex
        }
    }
}
