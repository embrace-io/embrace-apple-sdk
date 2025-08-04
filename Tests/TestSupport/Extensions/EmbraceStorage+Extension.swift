//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import Foundation

@testable import EmbraceStorageInternal

extension EmbraceStorage {
    public static func createInMemoryDb() throws -> EmbraceStorage {
        let storage = try EmbraceStorage(
            options: .init(storageMechanism: .inMemory(name: UUID().uuidString), enableBackgroundTasks: false),
            logger: MockLogger()
        )
        return storage
    }

    public static func createInDiskDb(fileName: String) throws -> EmbraceStorage {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
        let storage = try EmbraceStorage(
            options: .init(
                storageMechanism: .onDisk(name: fileName, baseURL: url, journalMode: .delete),
                enableBackgroundTasks: false),
            logger: MockLogger()
        )

        return storage
    }
}
