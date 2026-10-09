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

    func test_coreDataWrapper_onDisk_corruptStore_reportsLoadFailureInsteadOfCrashing() throws {
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
        // The store loads on the context's queue, so a corrupt one doesn't throw at init: the load failure
        // is reported, and later fetches and saves don't crash.
        let wrapper = try CoreDataWrapper(options: options, logger: MockLogger(), isTesting: false)

        let loaded = expectation(description: "initial load finished")
        var loadError: Error?
        wrapper.onInitialLoad { error in
            loadError = error
            loaded.fulfill()
        }
        wait(for: [loaded], timeout: .defaultTimeout)

        XCTAssertNotNil(loadError)
        XCTAssertFalse(wrapper.isStoreLoaded)
        XCTAssertEqual(wrapper.fetch(withRequest: SessionRecord.createFetchRequest()).count, 0)
        wrapper.performOperation { context in
            _ = SessionRecord.create(
                context: context,
                id: .random,
                processId: .random,
                state: .foreground,
                traceId: "trace",
                spanId: "span",
                startTime: Date()
            )
            XCTAssertFalse(wrapper.saveIfNeeded())
        }
    }
}
