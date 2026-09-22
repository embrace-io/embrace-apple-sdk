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

final class EmbraceStorageOnDiskTests: XCTestCase {

    func test_onDiskStore_persistsRecordsAcrossReopen() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let options = CoreDataWrapper.Options(
            storageMechanism: .onDisk(name: "roundtrip", baseURL: dir, journalMode: .delete),
            enableBackgroundTasks: false,
            entities: SpanRecord.entityDescriptions
        )

        // write a span to a real on-disk store (isTesting:false), then release the wrapper
        do {
            let wrapper = try CoreDataWrapper(options: options, logger: MockLogger(), isTesting: false)
            SpanRecord.create(context: wrapper.context, span: MockSpan(name: "survivor"))
            wrapper.save()
        }

        // reopen a fresh wrapper on the same file — the record must survive
        let reopened = try CoreDataWrapper(options: options, logger: MockLogger(), isTesting: false)
        let records: [SpanRecord] = reopened.fetch(withRequest: SpanRecord.createFetchRequest())

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.name, "survivor")
    }
}
