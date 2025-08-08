//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceStorageInternal
import Foundation
import OpenTelemetryApi
import TestSupport

class RandomError: Error, CustomNSError {
    static var errorDomain: String = "Embrace"
    var errorCode: Int = .random()
    var errorUserInfo: [String: Any] = .empty()
}

class SpyStorage: Storage {

    var didCallFetchAllResources = false
    var stubbedFetchAllResources: [EmbraceMetadata] = []
    func fetchAllResources() -> [EmbraceMetadata] {
        didCallFetchAllResources = true
        return stubbedFetchAllResources
    }

    var didCallFetchResourcesForSessionId = false
    var fetchResourcesForSessionIdReceivedParameter: SessionIdentifier!
    var stubbedFetchResourcesForSessionId: [EmbraceMetadata] = []
    func fetchResourcesForSessionId(_ sessionId: SessionIdentifier) -> [EmbraceMetadata] {
        didCallFetchResourcesForSessionId = true
        fetchResourcesForSessionIdReceivedParameter = sessionId
        return stubbedFetchResourcesForSessionId
    }

    var didCallFetchResourcesForProcessId = false
    var fetchResourcesForProcessIdReceivedParameter: ProcessIdentifier!
    var stubbedFetchResourcesForProcessId: [EmbraceMetadata] = []
    func fetchResourcesForProcessId(_ processId: ProcessIdentifier) -> [EmbraceMetadata] {
        didCallFetchResourcesForProcessId = true
        fetchResourcesForProcessIdReceivedParameter = processId
        return stubbedFetchResourcesForProcessId
    }

    var didCallFetchCustomPropertiesForSessionId = false
    var fetchCustomPropertiesForSessionIdReceivedParameter: SessionIdentifier!
    var stubbedFetchCustomPropertiesForSessionId: [EmbraceMetadata] = []
    func fetchCustomPropertiesForSessionId(_ sessionId: SessionIdentifier) -> [EmbraceMetadata] {
        didCallFetchCustomPropertiesForSessionId = true
        fetchCustomPropertiesForSessionIdReceivedParameter = sessionId
        return stubbedFetchCustomPropertiesForSessionId
    }

    var didCallFetchPersonaTagsForSessionId = false
    var fetchPersonaTagsForSessionIdReceivedParameter: SessionIdentifier!
    var stubbedFetchPersonaTagsForSessionId: [EmbraceMetadata] = []
    func fetchPersonaTagsForSessionId(_ sessionId: SessionIdentifier) -> [EmbraceMetadata] {
        didCallFetchPersonaTagsForSessionId = true
        fetchPersonaTagsForSessionIdReceivedParameter = sessionId
        return stubbedFetchPersonaTagsForSessionId
    }

    var didCallFetchPersonaTagsForProcessId = false
    var fetchPersonaTagsForProcessIdReceivedParameter: ProcessIdentifier!
    var stubbedFetchPersonaTagsForProcessId: [EmbraceMetadata] = []
    func fetchPersonaTagsForProcessId(_ processId: ProcessIdentifier) -> [EmbraceMetadata] {
        didCallFetchPersonaTagsForProcessId = true
        fetchPersonaTagsForProcessIdReceivedParameter = processId
        return stubbedFetchPersonaTagsForProcessId
    }

    var didCallCreate = false
    func createLog(
        id: LogIdentifier,
        processId: ProcessIdentifier,
        severity: LogSeverity,
        body: String,
        timestamp: Date,
        attributes: [String: AttributeValue]
    ) -> EmbraceLog? {
        didCallCreate = true

        return MockLog(
            id: id,
            processId: processId,
            severity: severity,
            body: body,
            timestamp: timestamp,
            attributes: attributes
        )
    }

    var didCallFetchAllExcludingProcessIdentifier = false
    var stubbedFetchAllExcludingProcessIdentifier: [EmbraceLog] = []
    var fetchAllExcludingProcessIdentifierReceivedParameter: EmbraceIdentifier!
    func fetchAll(excludingProcessIdentifier processIdentifier: EmbraceIdentifier) -> [EmbraceLog] {
        didCallFetchAllExcludingProcessIdentifier = true
        fetchAllExcludingProcessIdentifierReceivedParameter = processIdentifier
        return stubbedFetchAllExcludingProcessIdentifier
    }

    var didCallRemoveLogs = false
    var removeLogsReceivedParameter: [EmbraceLog] = []
    func remove(logs: [EmbraceLog]) {
        didCallRemoveLogs = true
        removeLogsReceivedParameter = logs
    }

    var didCallRemoveAllLogs = false
    func removeAllLogs() {
        didCallRemoveAllLogs = true
    }
}
