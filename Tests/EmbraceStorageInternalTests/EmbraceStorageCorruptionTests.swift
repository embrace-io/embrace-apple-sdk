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

final class EmbraceStorageCorruptionTests: XCTestCase {

    func test_coreDataWrapper_onDisk_corruptStore_throwsInsteadOfCrashing() throws {
        // copy the committed corrupted sqlite fixture to a unique on-disk location
        let fixturePath = try XCTUnwrap(
            Bundle.module.path(forResource: "db_corrupted", ofType: "sqlite", inDirectory: "Mocks")
        )
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let name = "db_corrupted"
        try FileManager.default.copyItem(
            atPath: fixturePath,
            toPath: dir.appendingPathComponent(name + ".sqlite").path
        )

        let options = CoreDataWrapper.Options(
            storageMechanism: .onDisk(name: name, baseURL: dir, journalMode: .delete),
            enableBackgroundTasks: false,
            entities: [SessionRecord.entityDescription]
        )

        // `isTesting: false` forces the real on-disk SQLite store (otherwise tests run in-memory).
        // A corrupt store must throw at init — failing fast — rather than crash later on first fetch/save.
        XCTAssertThrowsError(
            try CoreDataWrapper(options: options, logger: MockLogger(), isTesting: false)
        )
    }
}
