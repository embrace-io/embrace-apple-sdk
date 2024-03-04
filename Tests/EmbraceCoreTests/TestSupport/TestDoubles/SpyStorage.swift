//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorage
import EmbraceCommon

class RandomError: Error, CustomNSError {
    static var errorDomain: String = "Embrace"
    var errorCode: Int = .random()
    var errorUserInfo: [String: Any] = .empty()
}

class SpyStorage: Storage {
    private let shouldThrow: Bool

    init(shouldThrow: Bool = false) {
        self.shouldThrow = shouldThrow
    }

    var didCallFetchAllResources = false
    var stubbedFetchAllResources: [MetadataRecord] = []
    func fetchAllResources() throws -> [MetadataRecord] {
        didCallFetchAllResources = true
        guard !shouldThrow else {
            throw RandomError()
        }
        return stubbedFetchAllResources
    }

    var didCallFetchResourcesForSessionId = false
    var fetchResourcesForSessionIdReceivedParameter: SessionIdentifier!
    var stubbedFetchResourcesForSessionId: [MetadataRecord] = []
    func fetchResourcesForSessionId(_ sessionId: SessionIdentifier) throws -> [MetadataRecord] {
        didCallFetchResourcesForSessionId = true
        fetchResourcesForSessionIdReceivedParameter = sessionId
        guard !shouldThrow else {
            throw RandomError()
        }
        return stubbedFetchResourcesForSessionId
    }

    var didCallFetchAllCustomProperties = false
    var stubbedFetchAllCustomProperties: [MetadataRecord] = []
    func fetchAllCustomProperties() throws -> [MetadataRecord] {
        didCallFetchAllCustomProperties = true
        guard !shouldThrow else {
            throw RandomError()
        }
        return stubbedFetchAllCustomProperties
    }

    var didCallFetchCustomPropertiesForSessionId = false
    var fetchCustomPropertiesForSessionIdReceivedParameter: SessionIdentifier!
    var stubbedFetchCustomPropertiesForSessionId: [MetadataRecord] = []
    func fetchCustomPropertiesForSessionId(_ sessionId: SessionIdentifier) throws -> [MetadataRecord] {
        didCallFetchCustomPropertiesForSessionId = true
        fetchCustomPropertiesForSessionIdReceivedParameter = sessionId
        guard !shouldThrow else {
            throw RandomError()
        }
        return stubbedFetchCustomPropertiesForSessionId
    }

    var didCallCreate = false
    var stubbedCreateResult: Result<LogRecord, Error>?
    func create(_ log: LogRecord, completion: (Result<LogRecord, Error>) -> Void) {
        didCallCreate = true
        if let result = stubbedCreateResult {
            completion(result)
        }
    }

    var didCallFetchAllExcludingProcessIdentifier = false
    var stubbedFetchAllExcludingProcessIdentifier: [LogRecord] = []
    var fetchAllExcludingProcessIdentifierReceivedParameter: ProcessIdentifier!
    func fetchAll(excludingProcessIdentifier processIdentifier: ProcessIdentifier) throws -> [LogRecord] {
        didCallFetchAllExcludingProcessIdentifier = true
        guard !shouldThrow else {
            throw RandomError()
        }
        fetchAllExcludingProcessIdentifierReceivedParameter = processIdentifier
        return stubbedFetchAllExcludingProcessIdentifier
    }

    var didCallRemoveLogs = false
    var removeLogsReceivedParameter: [LogRecord] = []
    func remove(logs: [LogRecord]) throws {
        didCallRemoveLogs = true
        removeLogsReceivedParameter = logs
        guard !shouldThrow else {
            throw RandomError()
        }
    }

    var didCallRemoveAllLogs = false
    func removeAllLogs() throws {
        didCallRemoveAllLogs = true
        guard !shouldThrow else {
            throw RandomError()
        }
    }
}
