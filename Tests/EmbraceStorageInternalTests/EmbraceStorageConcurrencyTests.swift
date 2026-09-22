//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import Foundation
import TestSupport
import XCTest

@testable import EmbraceStorageInternal

final class EmbraceStorageConcurrencyTests: XCTestCase {

    func test_concurrentUpsertFetchCleanup_isThreadSafeAndConsistent() throws {
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        let count = 200
        let queue = DispatchQueue(label: "com.embrace.storage.stress", attributes: .concurrent)
        let group = DispatchGroup()

        // Hammer the shared background context from many threads at once: writers inserting distinct
        // open spans, readers counting, and cleanup passes — all interleaved. Open spans from the
        // current process are never eligible for cleanUpSpans, so the final count stays deterministic.
        for i in 0..<count {
            queue.async(group: group) {
                storage.upsertSpan(MockSpan(name: "span-\(i)"))
            }
            queue.async(group: group) {
                _ = storage.coreData.count(withRequest: SpanRecord.createFetchRequest())
            }
            queue.async(group: group) {
                storage.cleanUpSpans()
            }
        }

        let result = group.wait(timeout: .now() + 30)
        XCTAssertEqual(result, .success, "concurrent storage operations timed out (possible deadlock)")

        // every distinct span survived — nothing lost, duplicated, or corrupted under contention
        let total = storage.coreData.count(withRequest: SpanRecord.createFetchRequest())
        XCTAssertEqual(total, count)
    }
}
