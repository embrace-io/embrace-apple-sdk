//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorage
import GRDB

class ThrowingMigrationService: MigrationServiceProtocol {
    enum MigrationServiceError: Error {
        case alwaysError
    }

    let performsToThrow: [Int]
    private(set) var currentPerformCount: Int = 0

    /// - Parameters:
    ///    - performToThrow: The invocation of `perform` that should throw. Defaults to 1, the first call to `perform`.
    init(performToThrow: Int = 1) {
        self.performsToThrow = [performToThrow]
    }

    /// - Parameters:
    ///    - performToThrow: The invocation of `perform` that should throw. Defaults to 1, the first call to `perform`.
    init(performsToThrow: [Int]) {
        self.performsToThrow = performsToThrow
    }

    func perform(_ dbQueue: DatabaseWriter, migrations: [Migration]) throws {
        currentPerformCount += 1
        if performsToThrow.contains(currentPerformCount) {
            throw MigrationServiceError.alwaysError
        }
    }
}
