//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import EmbraceStorageInternal
import Foundation
import TestSupport

class SpyLogRepository: LogRepository {

    var didCallFetchAll = false
    var stubbedFetchAllResult: [EmbraceLog] = []
    func fetchAllLogs(excludingProcessIdentifier processIdentifier: EmbraceIdentifier) -> [EmbraceLog] {
        didCallFetchAll = true
        return stubbedFetchAllResult
    }

    var didCallRemoveLogs = false
    func remove(logs: [EmbraceLog]) {
        didCallRemoveLogs = true
    }

    var didCallCreate = false
    func saveLog(_ log: EmbraceLog) {
        didCallCreate = true
    }
}
