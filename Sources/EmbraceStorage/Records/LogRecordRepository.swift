//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public protocol LogRepository {
    func create(_ log: LogRecord, completion: (Result<LogRecord, Error>) -> Void)
}
