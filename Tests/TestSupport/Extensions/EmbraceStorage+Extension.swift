//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
@testable import EmbraceStorageInternal

public extension EmbraceStorage {
    static func createInMemoryDb(runMigrations: Bool = true) throws -> EmbraceStorage {
        let storage = try EmbraceStorage(
            options: .init(storageMechanism: .inMemory(name: UUID().uuidString)),
            logger: MockLogger()
        )
        return storage
    }

    static func createInDiskDb(fileName: String) throws -> EmbraceStorage {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
        let storage = try EmbraceStorage(
            options: .init(storageMechanism: .onDisk(name: fileName, baseURL: url)),
            logger: MockLogger()
        )

        return storage
    }
}
