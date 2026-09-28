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

    public static func createInDiskDb(fileName: String, journalMode: JournalMode = .delete) throws -> EmbraceStorage {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
        let storage = try EmbraceStorage(
            options: .init(
                storageMechanism: .onDisk(name: fileName, baseURL: url, journalMode: journalMode),
                enableBackgroundTasks: false),
            logger: MockLogger()
        )

        return storage
    }

    /// Blocks until every operation already queued on the Core Data context, such as an async insert
    /// or delete, has run. The context runs its blocks in order, so an empty synchronous block
    /// finishes only after everything queued before it.
    public func waitForPendingCoreDataOperations() {
        coreData.performOperation(allowMainQueue: true) { _ in }
    }
}
