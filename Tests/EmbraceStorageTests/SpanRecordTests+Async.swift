//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceStorage

extension SpanRecordTests {

    func test_addSpanAsync() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted span
        let expectation1 = XCTestExpectation()
        var span: SpanRecord?

        storage.addSpanAsync(id: "id", traceId: "traceId", type: .performance, data: Data(), startTime: Date(), endTime: nil) { result in
            switch result {
            case .success(let s):
                span = s
                expectation1.fulfill()
            case .failure(let error):
                XCTAssert(false, error.localizedDescription)
            }
        }

        wait(for: [expectation1], timeout: TestConstants.defaultTimeout)

        // then span should exist in storage
        let expectation2 = XCTestExpectation()
        if let span = span {
            try storage.dbQueue.read { db in
                XCTAssert(try span.exists(db))
                expectation2.fulfill()
            }
        } else {
            XCTAssert(false, "span is invalid!")
        }

        wait(for: [expectation2], timeout: TestConstants.defaultTimeout)
    }

    func test_upsertSpanAsync() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted span
        let expectation1 = XCTestExpectation()
        let span = SpanRecord(id: "id", traceId: "traceId", type: .performance, data: Data(), startTime: Date())

        storage.upsertSpanAsync(span) { result in
            switch result {
            case .success:
                expectation1.fulfill()
            case .failure(let error):
                XCTAssert(false, error.localizedDescription)
            }
        }

        wait(for: [expectation1], timeout: TestConstants.defaultTimeout)

        // then span should exist in storage
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssert(try span.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)
    }

    func test_fetchSpanAsync() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted span
        let original = try storage.addSpan(id: "id", traceId: "traceId", type: .performance, data: Data(), startTime: Date())

        // when fetching the span
        let expectation = XCTestExpectation()
        var span: SpanRecord?

        storage.fetchSpanAsync(id: "id", traceId: "traceId") { result in
            switch result {
            case .success(let s):
                span = s
                expectation.fulfill()
            case .failure(let error):
                XCTAssert(false, error.localizedDescription)
            }
        }

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)

        // then span should be valid
        XCTAssertEqual(original, span)
    }

    func test_fetchSpansAsync() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted spans
        let span1 = try storage.addSpan(id: "id1", traceId: "traceId", type: .performance, data: Data(), startTime: Date(), endTime: nil)
        let span2 = try storage.addSpan(id: "id2", traceId: "traceId", type: .performance, data: Data(), startTime: Date(), endTime: nil)
        let span3 = try storage.addSpan(id: "id3", traceId: "traceId", type: .performance, data: Data(), startTime: Date(), endTime: nil)

        // when fetching the spans
        let expectation = XCTestExpectation()

        storage.fetchSpansAsync(traceId: "traceId") { result in
            switch result {
            case .success(let spans):
                // then the fetched spans are valid
                XCTAssert(spans.contains(span1))
                XCTAssert(spans.contains(span2))
                XCTAssert(spans.contains(span3))
                expectation.fulfill()

            case .failure(let error):
                XCTAssert(false, error.localizedDescription)
            }
        }

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)
    }

    func test_fetchOpenSpansAsync() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted spans
        let span1 = try storage.addSpan(id: "id1", traceId: "traceId", type: .performance, data: Data(), startTime: Date(), endTime: nil)
        let span2 = try storage.addSpan(id: "id2", traceId: "traceId", type: .performance, data: Data(), startTime: Date(), endTime: Date(timeIntervalSinceNow: 10))
        let span3 = try storage.addSpan(id: "id3", traceId: "traceId", type: .performance, data: Data(), startTime: Date(), endTime: Date(timeIntervalSinceNow: 10))

        // when fetching the open spans
        let expectation = XCTestExpectation()

        storage.fetchOpenSpansAsync(traceId: "traceId") { result in
            switch result {
            case .success(let spans):
                // then the fetched spans are valid
                XCTAssert(spans.contains(span1))
                XCTAssertFalse(spans.contains(span2))
                XCTAssertFalse(spans.contains(span3))
                expectation.fulfill()

            case .failure(let error):
                XCTAssert(false, error.localizedDescription)
            }
        }

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)
    }

    func test_fetchOpenSpansAsync_type() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted spans
        let span1 = try storage.addSpan(id: "id1", traceId: "traceId", type: .performance, data: Data(), startTime: Date(), endTime: nil)
        let span2 = try storage.addSpan(id: "id2", traceId: "traceId", type: .performance, data: Data(), startTime: Date(), endTime: nil)
        let span3 = try storage.addSpan(id: "id3", traceId: "traceId", type: .ux, data: Data(), startTime: Date(), endTime: nil)

        // when fetching the open spans
        let expectation = XCTestExpectation()

        storage.fetchOpenSpansAsync(traceId: "traceId", type: .performance) { result in
            switch result {
            case .success(let spans):
                // then the fetched spans are valid
                XCTAssert(spans.contains(span1))
                XCTAssert(spans.contains(span2))
                XCTAssertFalse(spans.contains(span3))
                expectation.fulfill()

            case .failure(let error):
                XCTAssert(false, error.localizedDescription)
            }
        }

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)
    }

    func test_spanCountAsync_traceId() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted spans
        _ = try storage.addSpan(id: "id1", traceId: "traceId", type: .performance, data: Data(), startTime: Date(), endTime: nil)
        _ = try storage.addSpan(id: "id2", traceId: "traceId", type: .performance, data: Data(), startTime: Date(), endTime: nil)
        _ = try storage.addSpan(id: "id3", traceId: "traceId", type: .ux, data: Data(), startTime: Date(), endTime: nil)

        // when fetching the span count
        let expectation = XCTestExpectation()

        storage.spanCountAsync(traceId: "traceId", type: .performance) { result in
            switch result {
            case .success(let count):
                // then the count is correct
                XCTAssertEqual(count, 2)
                expectation.fulfill()

            case .failure(let error):
                XCTAssert(false, error.localizedDescription)
            }
        }

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)
    }

    func test_fetchSpansAsync_traceId_type() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted spans
        let span1 = try storage.addSpan(id: "id1", traceId: "traceId", type: .performance, data: Data(), startTime: Date(), endTime: nil)
        let span2 = try storage.addSpan(id: "id2", traceId: "traceId", type: .performance, data: Data(), startTime: Date(), endTime: nil)
        let span3 = try storage.addSpan(id: "id3", traceId: "traceId", type: .ux, data: Data(), startTime: Date(), endTime: nil)

        // when fetching the spans
        let expectation = XCTestExpectation()

        storage.fetchOpenSpansAsync(traceId: "traceId", type: .performance) { result in
            switch result {
            case .success(let spans):
                // then the fetched spans are valid
                XCTAssert(spans.contains(span1))
                XCTAssert(spans.contains(span2))
                XCTAssertFalse(spans.contains(span3))
                expectation.fulfill()

            case .failure(let error):
                XCTAssert(false, error.localizedDescription)
            }
        }

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)
    }

    func test_fetchSpansAsync_traceId_type_limit() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted spans
        let span1 = try storage.addSpan(id: "id1", traceId: "traceId", type: .performance, data: Data(), startTime: Date(timeIntervalSinceNow: 10), endTime: nil)
        let span2 = try storage.addSpan(id: "id2", traceId: "traceId", type: .performance, data: Data(), startTime: Date(), endTime: nil)
        let span3 = try storage.addSpan(id: "id3", traceId: "traceId", type: .performance, data: Data(), startTime: Date(timeIntervalSinceNow: 20), endTime: nil)

        // when fetching the spans
        let expectation = XCTestExpectation()

        storage.fetchSpansAsync(traceId: "traceId", type: .performance, limit: 1) { result in
            switch result {
            case .success(let spans):
                // then the fetched spans are valid
                XCTAssertEqual(spans.count, 1)
                XCTAssertFalse(spans.contains(span1))
                XCTAssert(spans.contains(span2))
                XCTAssertFalse(spans.contains(span3))
                expectation.fulfill()

            case .failure(let error):
                XCTAssert(false, error.localizedDescription)
            }
        }

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)
    }

    func test_spanCountAsync_date() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted spans
        let now = Date()
        _ = try storage.addSpan(id: "id1", traceId: "traceId", type: .performance, data: Data(), startTime: now, endTime: nil)
        _ = try storage.addSpan(id: "id2", traceId: "traceId", type: .performance, data: Data(), startTime: now.addingTimeInterval(10), endTime: nil)
        _ = try storage.addSpan(id: "id3", traceId: "traceId", type: .ux, data: Data(), startTime: now.addingTimeInterval(15), endTime: nil)

        // when fetching the span count
        let expectation = XCTestExpectation()

        storage.spanCountAsync(startTime: now.addingTimeInterval(5), type: .performance) { result in
            switch result {
            case .success(let count):
                // then the count is correct
                XCTAssertEqual(count, 1)
                expectation.fulfill()

            case .failure(let error):
                XCTAssert(false, error.localizedDescription)
            }
        }

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)
    }

    func test_fetchSpansAsync_date_type() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted spans
        let now = Date()
        let span1 = try storage.addSpan(id: "id1", traceId: "traceId", type: .performance, data: Data(), startTime: now, endTime: nil)
        let span2 = try storage.addSpan(id: "id2", traceId: "traceId", type: .performance, data: Data(), startTime: now.addingTimeInterval(10), endTime: nil)
        let span3 = try storage.addSpan(id: "id3", traceId: "traceId", type: .performance, data: Data(), startTime: now.addingTimeInterval(15), endTime: nil)

        // when fetching the spans
        let expectation = XCTestExpectation()

        storage.fetchSpansAsync(startTime: now.addingTimeInterval(5), type: .performance) { result in
            switch result {
            case .success(let spans):
                // then the fetched spans are valid
                XCTAssertFalse(spans.contains(span1))
                XCTAssert(spans.contains(span2))
                XCTAssert(spans.contains(span3))
                expectation.fulfill()

            case .failure(let error):
                XCTAssert(false, error.localizedDescription)
            }
        }

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)
    }

    func test_fetchSpansAsync_date_type_limit() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted spans
        let now = Date()
        let span1 = try storage.addSpan(id: "id1", traceId: "traceId", type: .performance, data: Data(), startTime: now, endTime: nil)
        let span2 = try storage.addSpan(id: "id2", traceId: "traceId", type: .performance, data: Data(), startTime: now.addingTimeInterval(10), endTime: nil)
        let span3 = try storage.addSpan(id: "id3", traceId: "traceId", type: .performance, data: Data(), startTime: now.addingTimeInterval(15), endTime: nil)

        // when fetching the spans
        let expectation = XCTestExpectation()

        storage.fetchSpansAsync(startTime: now.addingTimeInterval(5), type: .performance, limit: 1) { result in
            switch result {
            case .success(let spans):
                // then the fetched spans are valid
                XCTAssertEqual(spans.count, 1)
                XCTAssertFalse(spans.contains(span1))
                XCTAssert(spans.contains(span2))
                XCTAssertFalse(spans.contains(span3))
                expectation.fulfill()

            case .failure(let error):
                XCTAssert(false, error.localizedDescription)
            }
        }

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)
    }
}
