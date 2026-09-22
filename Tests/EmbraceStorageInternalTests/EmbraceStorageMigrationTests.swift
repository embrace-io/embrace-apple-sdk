//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import EmbraceCommonInternal
import EmbraceCoreDataInternal
import Foundation
import TestSupport
import XCTest

@testable import EmbraceStorageInternal

final class EmbraceStorageMigrationTests: XCTestCase {

    /// The v7 user-session columns were added as nullable/additive so a pre-v7 on-disk store
    /// lightweight-migrates on upgrade instead of failing to load (which would crash on launch).
    /// This seeds a pre-v7 store (current `SessionRecord` schema minus those columns), then opens
    /// it with the current model via `CoreDataWrapper` and asserts the row survives migration.
    func test_preV7Store_lightweightMigratesUserSessionColumns() throws {
        let userSessionColumns: Set<String> = [
            "userSessionIdRaw", "userSessionStartTime", "userSessionMaxDuration",
            "userSessionInactivityTimeout", "userSessionLastForegroundEnd",
            "userSessionPartIndex", "userSessionTerminationReason"
        ]

        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let name = "migration"
        let fileURL = dir.appendingPathComponent(name + ".sqlite")

        // 1) Build a pre-v7 model: the current Session entity minus the user-session columns.
        //    Properties must be copied (a property can't belong to two entities), and the class is
        //    generic NSManagedObject so we don't touch SessionRecord's @NSManaged user-session accessors.
        let oldEntity = NSEntityDescription()
        oldEntity.name = SessionRecord.entityName
        oldEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        oldEntity.properties =
            SessionRecord.entityDescription.properties
            .filter { !userSessionColumns.contains($0.name) }
            .compactMap { $0.copy() as? NSPropertyDescription }
        let oldModel = NSManagedObjectModel()
        oldModel.entities = [oldEntity]

        // 2) Create the pre-v7 on-disk store and write one session row.
        let oldCoordinator = NSPersistentStoreCoordinator(managedObjectModel: oldModel)
        let oldStore = try oldCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType, configurationName: nil, at: fileURL, options: nil)
        let oldContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        oldContext.persistentStoreCoordinator = oldCoordinator

        let row = NSEntityDescription.insertNewObject(forEntityName: SessionRecord.entityName, into: oldContext)
        row.setValue("session-1", forKey: "idRaw")
        row.setValue("proc-1", forKey: "processIdRaw")
        row.setValue("foreground", forKey: "state")
        row.setValue("trace-1", forKey: "traceId")
        row.setValue("span-1", forKey: "spanId")
        row.setValue(Date(), forKey: "startTime")
        row.setValue(Date(), forKey: "lastHeartbeatTime")
        row.setValue(false, forKey: "coldStart")
        row.setValue(false, forKey: "cleanExit")
        row.setValue(false, forKey: "appTerminated")
        try oldContext.save()
        try oldCoordinator.remove(oldStore)  // close the pre-v7 store

        // 3) Open the same file with the CURRENT model — triggers lightweight migration.
        let options = CoreDataWrapper.Options(
            storageMechanism: .onDisk(name: name, baseURL: dir, journalMode: .delete),
            enableBackgroundTasks: false,
            entities: [SessionRecord.entityDescription]
        )
        let wrapper = try CoreDataWrapper(options: options, logger: MockLogger(), isTesting: false)

        // 4) The pre-v7 row survived; the new user-session columns read back as nil/default.
        let records: [SessionRecord] = wrapper.fetch(withRequest: SessionRecord.createFetchRequest())
        XCTAssertEqual(records.count, 1)
        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(record.idRaw, "session-1")
        XCTAssertNil(record.userSessionIdRaw)
        XCTAssertNil(record.userSessionStartTime)
        XCTAssertNil(record.userSessionTerminationReason)
        XCTAssertEqual(record.userSessionPartIndex, 0)
    }
}
