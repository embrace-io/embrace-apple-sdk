//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import EmbraceCommonInternal
import EmbraceCoreDataInternal
import EmbraceStorageInternal
import Foundation

/// Fills the SDK's on-disk storage with `MetadataRecord` rows before the SDK is set up,
/// to measure how startup behaves when the metadata table is large.
///
/// Rows are process-scoped and owned by fake processes without sessions, which is what
/// metadata left behind by old launches looks like. The SDK deletes these rows during its
/// post-start cleanup, so the table is topped up again on every launch.
enum StorageSeeder {

    /// Must match the partition and storage path the SDK uses for the `bench` app id.
    static func storageURL(appId: String) -> URL? {
        try? FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("io.embrace.data/v6/\(appId)/storage")
    }

    static func seedMetadata(count: Int, appId: String) {
        guard count > 0, let url = storageURL(appId: appId) else {
            return
        }

        do {
            let storage = try EmbraceStorage(
                options: .init(storageMechanism: .onDisk(name: "EmbraceStorage", baseURL: url, journalMode: .wal)),
                logger: SilentLogger()
            )

            let existing = storage.coreData.count(withRequest: NSFetchRequest<MetadataRecord>(entityName: MetadataRecord.entityName))
            let missing = count - existing
            guard missing > 0 else {
                return
            }

            let batchSize = 1000
            let processesCount = max(1, missing / 20)

            storage.coreData.performOperation(allowMainQueue: true) { context in
                for index in 0..<missing {
                    let record = NSEntityDescription.insertNewObject(forEntityName: MetadataRecord.entityName, into: context) as! MetadataRecord
                    record.key = "bench.seed.\(index % 20)"
                    record.value = UUID().uuidString
                    record.typeRaw = MetadataRecordType.requiredResource.rawValue
                    record.lifespanRaw = MetadataRecordLifespan.process.rawValue
                    record.lifespanId = "seed-process-\(index % processesCount)"
                    record.collectedAt = Date()

                    if index % batchSize == batchSize - 1 {
                        try? context.save()
                        context.reset()
                    }
                }
                try? context.save()
                context.reset()
            }
        } catch {
            print("StorageSeeder failed: \(error)")
        }
    }
}

private final class SilentLogger: NSObject, InternalLogger {
    func trace(_ message: String, attributes: [String: String]) -> Bool { true }
    func trace(_ message: String) -> Bool { true }
    func debug(_ message: String, attributes: [String: String]) -> Bool { true }
    func debug(_ message: String) -> Bool { true }
    func info(_ message: String, attributes: [String: String]) -> Bool { true }
    func info(_ message: String) -> Bool { true }
    func warning(_ message: String, attributes: [String: String]) -> Bool { true }
    func warning(_ message: String) -> Bool { true }
    func error(_ message: String, attributes: [String: String]) -> Bool { true }
    func error(_ message: String) -> Bool { true }
    func startup(_ message: String, attributes: [String: String]) -> Bool { true }
    func startup(_ message: String) -> Bool { true }
    func critical(_ message: String, attributes: [String: String]) -> Bool { true }
    func critical(_ message: String) -> Bool { true }
}
