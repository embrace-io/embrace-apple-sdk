//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorageInternal
import EmbraceCommonInternal
import OpenTelemetryApi

class RandomError: Error, CustomNSError {
    static var errorDomain: String = "Embrace"
    var errorCode: Int = .random()
    var errorUserInfo: [String: Any] = .empty()
}

class SpyStorage: Storage {

    var didCallFetchAllResources = false
    var stubbedFetchAllResources: [MetadataRecord] = []
    func fetchAllResources() -> [MetadataRecord] {
        didCallFetchAllResources = true
        return stubbedFetchAllResources
    }

    var didCallFetchResourcesForSessionId = false
    var fetchResourcesForSessionIdReceivedParameter: SessionIdentifier!
    var stubbedFetchResourcesForSessionId: [MetadataRecord] = []
    func fetchResourcesForSessionId(_ sessionId: SessionIdentifier) -> [MetadataRecord] {
        didCallFetchResourcesForSessionId = true
        fetchResourcesForSessionIdReceivedParameter = sessionId
        return stubbedFetchResourcesForSessionId
    }

    var didCallFetchResourcesForProcessId = false
    var fetchResourcesForProcessIdReceivedParameter: ProcessIdentifier!
    var stubbedFetchResourcesForProcessId: [MetadataRecord] = []
    func fetchResourcesForProcessId(_ processId: ProcessIdentifier) -> [MetadataRecord] {
        didCallFetchResourcesForProcessId = true
        fetchResourcesForProcessIdReceivedParameter = processId
        return stubbedFetchResourcesForProcessId
    }

    var didCallFetchCustomPropertiesForSessionId = false
    var fetchCustomPropertiesForSessionIdReceivedParameter: SessionIdentifier!
    var stubbedFetchCustomPropertiesForSessionId: [MetadataRecord] = []
    func fetchCustomPropertiesForSessionId(_ sessionId: SessionIdentifier) -> [MetadataRecord] {
        didCallFetchCustomPropertiesForSessionId = true
        fetchCustomPropertiesForSessionIdReceivedParameter = sessionId
        return stubbedFetchCustomPropertiesForSessionId
    }

    var didCallFetchPersonaTagsForSessionId = false
    var fetchPersonaTagsForSessionIdReceivedParameter: SessionIdentifier!
    var stubbedFetchPersonaTagsForSessionId: [MetadataRecord] = []
    func fetchPersonaTagsForSessionId(_ sessionId: SessionIdentifier) -> [MetadataRecord] {
        didCallFetchPersonaTagsForSessionId = true
        fetchPersonaTagsForSessionIdReceivedParameter = sessionId
        return stubbedFetchPersonaTagsForSessionId
    }

    var didCallFetchPersonaTagsForProcessId = false
    var fetchPersonaTagsForProcessIdReceivedParameter: ProcessIdentifier!
    var stubbedFetchPersonaTagsForProcessId: [MetadataRecord] = []
    func fetchPersonaTagsForProcessId(_ processId: ProcessIdentifier) -> [MetadataRecord] {
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
        attributes: [String : AttributeValue]
    ) -> LogRecord {
        didCallCreate = true

        return LogRecord(
            id: id,
            processId: processId,
            severity: severity,
            body: body,
            timestamp: timestamp,
            attributes: attributes
        )
    }

    var didCallFetchAllExcludingProcessIdentifier = false
    var stubbedFetchAllExcludingProcessIdentifier: [LogRecord] = []
    var fetchAllExcludingProcessIdentifierReceivedParameter: ProcessIdentifier!
    func fetchAll(excludingProcessIdentifier processIdentifier: ProcessIdentifier) -> [LogRecord] {
        didCallFetchAllExcludingProcessIdentifier = true
        fetchAllExcludingProcessIdentifierReceivedParameter = processIdentifier
        return stubbedFetchAllExcludingProcessIdentifier
    }

    var didCallRemoveLogs = false
    var removeLogsReceivedParameter: [LogRecord] = []
    func remove(logs: [LogRecord]) {
        didCallRemoveLogs = true
        removeLogsReceivedParameter = logs
    }

    var didCallRemoveAllLogs = false
    func removeAllLogs() {
        didCallRemoveAllLogs = true
    }
}
