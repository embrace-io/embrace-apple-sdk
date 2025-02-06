//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorageInternal
import GRDB

class ThrowingMigration: Migration {
    enum MigrationServiceError: Error {
        case alwaysError
    }

    static var identifier = "AlwaysThrowingMigration"

    let performsToThrow: [Int]
    private(set) var currentPerformCount: Int = 0

    /// - Parameters:
    ///    - performToThrow: The invocation of `perform` that should throw. Defaults to 1, the first call to `perform`.
    init(performsToThrow: [Int]) {
        self.performsToThrow = performsToThrow
    }

    /// - Parameters:
    ///    - performToThrow: The invocation of `perform` that should throw. Defaults to 1, the first call to `perform`.
    convenience init(performToThrow: Int = 1) {
        self.init(performsToThrow: [performToThrow])
    }

    func perform(_ db: GRDB.Database) throws {
        currentPerformCount += 1
        if performsToThrow.contains(currentPerformCount) {
            throw MigrationServiceError.alwaysError
        }
    }
}
