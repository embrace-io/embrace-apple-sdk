//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import EmbraceStorageInternal
import Foundation
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
    var fetchResourcesForSessionIdReceivedParameter: EmbraceIdentifier!
    var stubbedFetchResourcesForSessionId: [EmbraceMetadata] = []
    func fetchResourcesForSessionId(_ sessionId: EmbraceIdentifier) -> [EmbraceMetadata] {
        didCallFetchResourcesForSessionId = true
        fetchResourcesForSessionIdReceivedParameter = sessionId
        return stubbedFetchResourcesForSessionId
    }

    var didCallFetchResourcesForProcessId = false
    var fetchResourcesForProcessIdReceivedParameter: EmbraceIdentifier!
    var stubbedFetchResourcesForProcessId: [EmbraceMetadata] = []
    func fetchResourcesForProcessId(_ processId: EmbraceIdentifier) -> [EmbraceMetadata] {
        didCallFetchResourcesForProcessId = true
        fetchResourcesForProcessIdReceivedParameter = processId
        return stubbedFetchResourcesForProcessId
    }

    var didCallFetchCustomPropertiesForSessionId = false
    var fetchCustomPropertiesForSessionIdReceivedParameter: EmbraceIdentifier!
    var stubbedFetchCustomPropertiesForSessionId: [EmbraceMetadata] = []
    func fetchCustomPropertiesForSessionId(_ sessionId: EmbraceIdentifier) -> [EmbraceMetadata] {
        didCallFetchCustomPropertiesForSessionId = true
        fetchCustomPropertiesForSessionIdReceivedParameter = sessionId
        return stubbedFetchCustomPropertiesForSessionId
    }

    var didCallFetchPersonaTagsForSessionId = false
    var fetchPersonaTagsForSessionIdReceivedParameter: EmbraceIdentifier!
    var stubbedFetchPersonaTagsForSessionId: [EmbraceMetadata] = []
    func fetchPersonaTagsForSessionId(_ sessionId: EmbraceIdentifier) -> [EmbraceMetadata] {
        didCallFetchPersonaTagsForSessionId = true
        fetchPersonaTagsForSessionIdReceivedParameter = sessionId
        return stubbedFetchPersonaTagsForSessionId
    }

    var didCallFetchPersonaTagsForProcessId = false
    var fetchPersonaTagsForProcessIdReceivedParameter: EmbraceIdentifier!
    var stubbedFetchPersonaTagsForProcessId: [EmbraceMetadata] = []
    func fetchPersonaTagsForProcessId(_ processId: EmbraceIdentifier) -> [EmbraceMetadata] {
        didCallFetchPersonaTagsForProcessId = true
        fetchPersonaTagsForProcessIdReceivedParameter = processId
        return stubbedFetchPersonaTagsForProcessId
    }

    var didCallCreate = false
    func saveLog(_ log: EmbraceLog) {
        didCallCreate = true
    }

    var didCallFetchAllExcludingProcessIdentifier = false
    var stubbedFetchAllExcludingProcessIdentifier: [EmbraceLog] = []
    var fetchAllExcludingProcessIdentifierReceivedParameter: EmbraceIdentifier!
    func fetchAllLogs(excludingProcessIdentifier processIdentifier: EmbraceIdentifier) -> [EmbraceLog] {
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
}
