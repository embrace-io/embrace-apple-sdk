//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import XCTest

@testable import EmbraceCore
@testable import EmbraceStorageInternal

class MockMetadataFetcher: EmbraceStorageMetadataFetcher {
    var metadata: [EmbraceMetadata]

    init(metadata: [EmbraceMetadata] = []) {
        self.metadata = metadata
    }

    func fetchAllResources() -> [EmbraceMetadata] {
        return metadata
    }

    func fetchResourcesForSessionId(_ sessionId: EmbraceIdentifier) -> [EmbraceMetadata] {
        return metadata.filter { record in
            (record.type == .resource || record.type == .requiredResource)
        }
    }

    func fetchResourcesForProcessId(_ processId: EmbraceIdentifier) -> [EmbraceMetadata] {
        return metadata.filter { record in
            (record.type == .resource || record.type == .requiredResource) && record.lifespan == .process
                && record.lifespanId == processId.stringValue
        }
    }

    func fetchCustomPropertiesForSessionId(_ sessionId: EmbraceIdentifier) -> [EmbraceMetadata] {
        return metadata.filter { record in
            record.type == .customProperty && record.lifespan == .session && record.lifespanId == sessionId.stringValue
        }
    }

    func fetchPersonaTagsForSessionId(_ sessionId: EmbraceIdentifier) -> [EmbraceMetadata] {
        return metadata.filter { record in
            record.type == .personaTag && record.lifespan == .session && record.lifespanId == sessionId.stringValue
        }
    }

    func fetchPersonaTagsForProcessId(_ processId: EmbraceIdentifier) -> [EmbraceMetadata] {
        return metadata.filter { record in
            record.type == .personaTag && record.lifespan == .process && record.lifespanId == processId.stringValue
        }
    }
}
