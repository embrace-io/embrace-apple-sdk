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

    var didCallFetchResourcesForUserSessionId = false
    var fetchResourcesForUserSessionIdReceivedParameter: EmbraceIdentifier!
    var fetchResourcesForUserSessionIdReceivedProcessId: EmbraceIdentifier!
    var stubbedFetchResourcesForUserSessionId: [EmbraceMetadata] = []
    var stubbedFetchResourcesForUserSessionIdMap: [String: [EmbraceMetadata]] = [:]
    func fetchResources(userSessionId: EmbraceIdentifier?, processId: EmbraceIdentifier) -> [EmbraceMetadata] {
        didCallFetchResourcesForUserSessionId = true
        fetchResourcesForUserSessionIdReceivedParameter = userSessionId
        fetchResourcesForUserSessionIdReceivedProcessId = processId

        if let userSessionId, let stubbed = stubbedFetchResourcesForUserSessionIdMap[userSessionId.stringValue] {
            return stubbed
        }

        return stubbedFetchResourcesForUserSessionId
    }

    var didCallFetchResourcesForProcessId = false
    var fetchResourcesForProcessIdReceivedParameter: EmbraceIdentifier!
    var stubbedFetchResourcesForProcessId: [EmbraceMetadata] = []
    func fetchResourcesForProcessId(_ processId: EmbraceIdentifier) -> [EmbraceMetadata] {
        didCallFetchResourcesForProcessId = true
        fetchResourcesForProcessIdReceivedParameter = processId
        return stubbedFetchResourcesForProcessId
    }

    var didCallFetchCustomPropertiesForUserSessionId = false
    var fetchCustomPropertiesForUserSessionIdReceivedParameter: EmbraceIdentifier!
    var fetchCustomPropertiesForUserSessionIdReceivedProcessId: EmbraceIdentifier!
    var stubbedFetchCustomPropertiesForUserSessionId: [EmbraceMetadata] = []
    func fetchCustomProperties(userSessionId: EmbraceIdentifier?, processId: EmbraceIdentifier) -> [EmbraceMetadata] {
        didCallFetchCustomPropertiesForUserSessionId = true
        fetchCustomPropertiesForUserSessionIdReceivedParameter = userSessionId
        fetchCustomPropertiesForUserSessionIdReceivedProcessId = processId
        return stubbedFetchCustomPropertiesForUserSessionId
    }

    var didCallFetchPersonaTagsForUserSessionId = false
    var fetchPersonaTagsForUserSessionIdReceivedParameter: EmbraceIdentifier!
    var fetchPersonaTagsForUserSessionIdReceivedProcessId: EmbraceIdentifier!
    var stubbedFetchPersonaTagsForUserSessionId: [EmbraceMetadata] = []
    func fetchPersonaTags(userSessionId: EmbraceIdentifier?, processId: EmbraceIdentifier) -> [EmbraceMetadata] {
        didCallFetchPersonaTagsForUserSessionId = true
        fetchPersonaTagsForUserSessionIdReceivedParameter = userSessionId
        fetchPersonaTagsForUserSessionIdReceivedProcessId = processId
        return stubbedFetchPersonaTagsForUserSessionId
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
    func fetchAllLogs(excludingProcessIdentifier processIdentifier: EmbraceIdentifier?) -> [EmbraceLog] {
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
