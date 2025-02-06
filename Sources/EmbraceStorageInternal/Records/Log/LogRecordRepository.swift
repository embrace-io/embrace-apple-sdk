//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal

public protocol LogRepository {
    func create(_ log: LogRecord, completion: (Result<LogRecord, Error>) -> Void)
    func fetchAll(excludingProcessIdentifier processIdentifier: ProcessIdentifier) throws -> [LogRecord]
    func remove(logs: [LogRecord]) throws
    func removeAllLogs() throws
}
