//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceStorage

class SpyLogRepository: LogRepository {
    var didCallCreate: Bool = false
    var stubbedCreateCompletionResult: (Result<LogRecord, Error>)?
    func create(_ log: LogRecord, completion: (Result<LogRecord, Error>) -> Void) {
        didCallCreate = true
        if let result = stubbedCreateCompletionResult {
            completion(result)
        }
    }
}
