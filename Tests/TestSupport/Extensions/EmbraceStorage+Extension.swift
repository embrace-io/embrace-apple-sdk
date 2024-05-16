//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
@testable import EmbraceStorage

public extension EmbraceStorage {
    static func createInMemoryDb(runMigrations: Bool = true) throws -> EmbraceStorage {
        let storage = try EmbraceStorage(options: .init(named: UUID().uuidString))
        if runMigrations { try storage.performMigration() }
        return storage
    }

    static func createInDiskDb(runMigrations: Bool = true) throws -> EmbraceStorage {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
        let storage = try EmbraceStorage(
            options: .init(baseUrl: url, fileName: "\(UUID().uuidString).sqlite")
        )

        if runMigrations { try storage.performMigration() }
        return storage
    }
}

public extension EmbraceStorage {
    func teardown() throws {
        try dbQueue.close()
    }
}
