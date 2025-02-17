//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
import XCTest
@testable import EmbraceCore
@testable import EmbraceStorageInternal
import EmbraceCommonInternal

class MockMetadataFetcher: EmbraceStorageMetadataFetcher {
    var metadata: [EmbraceMetadata]

    init(metadata: [EmbraceMetadata] = []) {
        self.metadata = metadata
    }

    func fetchAllResources() -> [EmbraceMetadata] {
        return metadata
    }

    func fetchResourcesForSessionId(_ sessionId: SessionIdentifier) -> [EmbraceMetadata] {
        return metadata.filter { record in
            (record.type == .resource || record.type == .requiredResource)
        }
    }

    func fetchResourcesForProcessId(_ processId: ProcessIdentifier) -> [EmbraceMetadata] {
        return metadata.filter { record in
            (record.type == .resource || record.type == .requiredResource) &&
            record.lifespan == .process &&
            record.lifespanId == processId.hex
        }
    }

    func fetchCustomPropertiesForSessionId(_ sessionId: SessionIdentifier) -> [EmbraceMetadata] {
        return metadata.filter { record in
            record.type == .customProperty &&
            record.lifespan == .session &&
            record.lifespanId == sessionId.toString
        }
    }

    func fetchPersonaTagsForSessionId(_ sessionId: SessionIdentifier) -> [EmbraceMetadata] {
        return metadata.filter { record in
            record.type == .personaTag &&
            record.lifespan == .session &&
            record.lifespanId == sessionId.toString
        }
    }

    func fetchPersonaTagsForProcessId(_ processId: ProcessIdentifier) -> [EmbraceMetadata] {
        return metadata.filter { record in
            record.type == .personaTag &&
            record.lifespan == .process &&
            record.lifespanId == processId.hex
        }
    }
}
