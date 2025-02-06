//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import GRDB

public protocol Migration {
    /// The identifier to register this migration under. Must be unique
    static var identifier: StringLiteralType { get }

    /// Controls how this migration handles foreign key constraints. Defaults to `immediate`.
    static var foreignKeyChecks: DatabaseMigrator.ForeignKeyChecks { get }

    /// Operation that performs migration.
    /// See [GRDB Reference](https://swiftpackageindex.com/groue/grdb.swift/master/documentation/grdb/migrations).
    func perform(_ db: Database) throws
}

extension Migration {
    var identifier: StringLiteralType { Self.identifier }
    var foreignKeyChecks: DatabaseMigrator.ForeignKeyChecks { Self.foreignKeyChecks }
}

extension Migration {
    public static var foreignKeyChecks: DatabaseMigrator.ForeignKeyChecks { .immediate }
}
