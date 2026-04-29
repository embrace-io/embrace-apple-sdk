//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)

    import Darwin
    import EmbraceProfilingSampler
    import XCTest

    /// Tests for the ring buffer under concurrent access.
    ///
    /// Simulates the production scenario: one periodic writer (100 ms cadence)
    /// and multiple simultaneous readers. All assertions run inside the reader
    /// threads so that race-condition failures are caught as XCTest failures.
    final class RingBufferConcurrencyTests: XCTestCase {

        // MARK: - Shared test state

        /// Thread-safe bag used by reader tasks to accumulate failure messages.
        private final class FailureCollector {
            private let lock = NSLock()
            private(set) var messages: [String] = []

            func record(_ msg: String) {
                lock.lock()
                messages.append(msg)
                lock.unlock()
            }
        }

        /// Thread-safe stop flag for reader loops.
        private final class StopFlag {
            private let lock = NSLock()
            private var _stop = false
            var isSet: Bool {
                lock.lock()
                defer { lock.unlock() }
                return _stop
            }
            func set() {
                lock.lock()
                _stop = true
                lock.unlock()
            }
        }

        // MARK: - Helpers

        /// Write-pattern sentinel: frame[j] of write-index `idx` = idx * 10_000 + j + 1.
        private func makeFrames(writeIndex: Int, count: Int) -> [UInt] {
            let base = UInt(writeIndex) * 10_000
            return (0..<count).map { base + UInt($0) + 1 }
        }

        /// Verify a single record against the write pattern.
        private func frameError(_ rec: TestRecord, intervalNs: UInt64) -> String? {
            guard intervalNs > 0 else { return nil }
            let idx = Int(rec.timestamp_ns / intervalNs)
            let base = UInt(idx) * 10_000
            for j in 0..<rec.frame_count {
                let expected = base + UInt(j) + 1
                if rec.frames[j] != expected {
                    return "ts=\(rec.timestamp_ns) frame[\(j)]: expected \(expected), got \(rec.frames[j])"
                }
            }
            return nil
        }

        /// Spin up `readerCount` concurrent readers while `writerBlock` runs on the calling thread.
        private func runWithReaders(
            buf: UnsafeMutablePointer<emb_ring_buffer_t>,
            readerCount: Int,
            validate: @escaping ([TestRecord], FailureCollector) -> Void,
            writerBlock: (FailureCollector) -> Void
        ) -> FailureCollector {
            let failures = FailureCollector()
            let stop = StopFlag()
            let group = DispatchGroup()
            let queue = DispatchQueue(label: "ring.test.readers", attributes: .concurrent)

            let capacity = emb_ring_buffer_capacity(buf)

            for _ in 0..<readerCount {
                group.enter()
                queue.async {
                    let output = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
                    defer { output.deallocate() }

                    while !stop.isSet {
                        let result = emb_ring_buffer_read_range(
                            buf, 0, UINT64_MAX, output, capacity)
                        let records = parseRecords(output, result)
                        validate(records, failures)
                    }
                    group.leave()
                }
            }

            writerBlock(failures)
            stop.set()
            group.wait()

            return failures
        }

        private func assertNoFailures(_ fc: FailureCollector) {
            for msg in fc.messages { XCTFail(msg) }
        }

        // MARK: - Tests

        /// 100 ms periodic writer, 4 readers: frame data must be internally consistent.
        func test_periodicWriter_multipleReaders_noFrameCorruption() {
            let buf = emb_ring_buffer_create(1 * 1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let intervalNs: UInt64 = 100_000_000
            let writeCount = 10
            let frameCount = 20

            let failures = runWithReaders(
                buf: buf, readerCount: 4,
                validate: { records, fc in
                    for i in 0..<records.count {
                        if let err = self.frameError(records[i], intervalNs: intervalNs) {
                            fc.record("Frame corruption: \(err)")
                        }
                    }
                },
                writerBlock: { _ in
                    for i in 0..<writeCount {
                        let f = self.makeFrames(writeIndex: i, count: frameCount)
                        emb_ring_buffer_write(buf, UInt64(i) * intervalNs, f, frameCount)
                        Thread.sleep(forTimeInterval: 0.001)
                    }
                }
            )

            assertNoFailures(failures)
        }

        /// Each read result must have strictly ascending timestamps.
        func test_periodicWriter_multipleReaders_timestampsAscendingWithinResult() {
            let buf = emb_ring_buffer_create(1 * 1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let failures = runWithReaders(
                buf: buf, readerCount: 4,
                validate: { records, fc in
                    guard records.count > 1 else { return }
                    for i in 1..<records.count {
                        let prev = records[i - 1].timestamp_ns
                        let cur = records[i].timestamp_ns
                        if cur <= prev {
                            fc.record("Non-ascending timestamps at index \(i): \(prev) >= \(cur)")
                        }
                    }
                },
                writerBlock: { _ in
                    for i in 0..<10 {
                        let f: [UInt] = [UInt(i + 1)]
                        emb_ring_buffer_write(buf, UInt64(i + 1) * 100_000_000, f, 1)
                        Thread.sleep(forTimeInterval: 0.001)
                    }
                }
            )

            assertNoFailures(failures)
        }

        /// Every returned record must have believable frame_count (≤ 10 000).
        func test_periodicWriter_multipleReaders_recordStructureAlwaysValid() {
            let buf = emb_ring_buffer_create(1 * 1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let failures = runWithReaders(
                buf: buf, readerCount: 4,
                validate: { records, fc in
                    for i in 0..<records.count {
                        let rec = records[i]
                        if rec.frame_count > 10_000 {
                            fc.record("record[\(i)].frame_count=\(rec.frame_count) is impossibly large")
                        }
                    }
                },
                writerBlock: { _ in
                    for i in 0..<10 {
                        let fc = (i % 8) + 1
                        let f = self.makeFrames(writeIndex: i, count: fc)
                        emb_ring_buffer_write(buf, UInt64(i + 1) * 100_000_000, f, fc)
                        Thread.sleep(forTimeInterval: 0.001)
                    }
                }
            )

            assertNoFailures(failures)
        }

        /// Readers survive a one-page buffer wrapping many times.
        func test_periodicWriter_multipleReaders_wrapAroundNoCrash() {
            let buf = emb_ring_buffer_create(4 * Int(getpagesize()))!
            defer { emb_ring_buffer_destroy(buf) }

            let failures = runWithReaders(
                buf: buf, readerCount: 4,
                validate: { records, fc in
                    for i in 0..<records.count {
                        if records[i].frame_count > 10_000 {
                            fc.record("wrap-around: record[\(i)].frame_count is corrupt")
                        }
                    }
                },
                writerBlock: { _ in
                    for i in 0..<60 {
                        let fc = (i % 12) + 1
                        let f = self.makeFrames(writeIndex: i, count: fc)
                        emb_ring_buffer_write(buf, UInt64(i + 1) * 100_000_000, f, fc)
                        Thread.sleep(forTimeInterval: 0.001)
                    }
                }
            )

            assertNoFailures(failures)
        }

        /// Readers survive evictions happening while they are mid-read.
        func test_periodicWriter_multipleReaders_evictionDuringRead() {
            let buf = emb_ring_buffer_create(Int(getpagesize()))!
            defer { emb_ring_buffer_destroy(buf) }

            let failures = runWithReaders(
                buf: buf, readerCount: 6,
                validate: { records, fc in
                    for i in 0..<records.count {
                        if records[i].frame_count > 10_000 {
                            fc.record("eviction: record[\(i)].frame_count corrupt")
                        }
                    }
                    guard records.count > 1 else { return }
                    for i in 1..<records.count {
                        let prev = records[i - 1].timestamp_ns
                        let cur = records[i].timestamp_ns
                        if cur < prev {
                            fc.record("eviction: timestamp went backwards \(prev) → \(cur)")
                        }
                    }
                },
                writerBlock: { _ in
                    for i in 0..<40 {
                        let f = self.makeFrames(writeIndex: i, count: 10)
                        emb_ring_buffer_write(buf, UInt64(i + 1) * 100_000_000, f, 10)
                        Thread.sleep(forTimeInterval: 0.001)
                    }
                }
            )

            assertNoFailures(failures)
        }

        /// Many concurrent readers all read simultaneously after a batch of writes.
        func test_simultaneousReaders_sameBuffer_consistentResults() {
            let buf = emb_ring_buffer_create(1 * 1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for i in 0..<20 {
                let fc = (i % 5) + 1
                let f = makeFrames(writeIndex: i, count: fc)
                emb_ring_buffer_write(buf, UInt64(i + 1) * 1_000_000, f, fc)
            }

            let readerCount = 8
            let resultsLock = NSLock()
            var snapshots = [[UInt64]]()
            let group = DispatchGroup()
            let queue = DispatchQueue(label: "ring.simultaneous", attributes: .concurrent)
            let capacity = emb_ring_buffer_capacity(buf)

            for _ in 0..<readerCount {
                group.enter()
                queue.async {
                    let output = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
                    defer { output.deallocate() }

                    let result = emb_ring_buffer_read_range(buf, 0, UINT64_MAX, output, capacity)
                    let records = parseRecords(output, result)
                    let ts = records.map { $0.timestamp_ns }
                    resultsLock.lock()
                    snapshots.append(ts)
                    resultsLock.unlock()
                    group.leave()
                }
            }
            group.wait()

            let ref = snapshots[0]
            for r in 1..<snapshots.count {
                XCTAssertEqual(
                    snapshots[r], ref,
                    "reader \(r) got different timestamps than reader 0")
            }
        }

        /// Windowed readers must only ever see records inside their requested range.
        func test_periodicWriter_rangeReaders_onlySeeWindowedRecords() {
            let buf = emb_ring_buffer_create(1 * 1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let intervalNs: UInt64 = 100_000_000
            let windowStart: UInt64 = 2 * intervalNs
            let windowEnd: UInt64 = 7 * intervalNs

            let failures = FailureCollector()
            let stop = StopFlag()
            let group = DispatchGroup()
            let queue = DispatchQueue(label: "ring.window.readers", attributes: .concurrent)
            let capacity = emb_ring_buffer_capacity(buf)

            for _ in 0..<4 {
                group.enter()
                queue.async {
                    let output = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
                    defer { output.deallocate() }

                    while !stop.isSet {
                        let result = emb_ring_buffer_read_range(
                            buf, windowStart, windowEnd, output, capacity)
                        let records = parseRecords(output, result)
                        for i in 0..<records.count {
                            let ts = records[i].timestamp_ns
                            if ts < windowStart || ts > windowEnd {
                                failures.record("windowed read: ts=\(ts) outside [\(windowStart), \(windowEnd)]")
                            }
                        }
                    }
                    group.leave()
                }
            }

            for i in 0..<10 {
                let f: [UInt] = [UInt(i + 1)]
                emb_ring_buffer_write(buf, UInt64(i) * intervalNs, f, 1)
                Thread.sleep(forTimeInterval: 0.001)
            }
            stop.set()
            group.wait()

            assertNoFailures(failures)
        }

        /// Stress: 8 readers + high-frequency writer (no sleep between writes).
        func test_stress_highFrequencyWriter_manyReaders_noCrash() {
            let buf = emb_ring_buffer_create(2 * Int(getpagesize()))!
            defer { emb_ring_buffer_destroy(buf) }

            let unbelievableFrameCount = 1_000_000

            let failures = FailureCollector()
            let stop = StopFlag()
            let group = DispatchGroup()
            let queue = DispatchQueue(label: "ring.stress.readers", attributes: .concurrent)
            let capacity = emb_ring_buffer_capacity(buf)

            for _ in 0..<8 {
                group.enter()
                queue.async {
                    let output = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
                    defer { output.deallocate() }

                    while !stop.isSet {
                        let result = emb_ring_buffer_read_range(
                            buf, 0, UINT64_MAX, output, capacity)
                        let records = parseRecords(output, result)
                        for i in 0..<records.count {
                            if records[i].frame_count > unbelievableFrameCount {
                                failures.record("stress: frame_count \(records[i].frame_count) exceeds implementation limit")
                            }
                        }
                    }
                    group.leave()
                }
            }

            let deadline = Date().addingTimeInterval(0.5)
            var writeCount = 0
            while Date() < deadline {
                let fc = (writeCount % 10) + 1
                let f = makeFrames(writeIndex: writeCount, count: fc)
                emb_ring_buffer_write(buf, UInt64(writeCount + 1) * 1_000_000, f, fc)
                writeCount += 1
            }

            stop.set()
            group.wait()

            assertNoFailures(failures)
            XCTAssertGreaterThan(writeCount, 0)
        }

        /// Three non-overlapping range readers: no reader ever sees a record outside its window.
        func test_periodicWriter_partitionedRangeReaders_noRangeViolation() {
            let buf = emb_ring_buffer_create(1 * 1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            let intervalNs: UInt64 = 100_000_000
            let windows: [(start: UInt64, end: UInt64)] = [
                (0, 3 * intervalNs),
                (3 * intervalNs + 1, 6 * intervalNs),
                (6 * intervalNs + 1, 9 * intervalNs)
            ]

            let failures = FailureCollector()
            let stop = StopFlag()
            let group = DispatchGroup()
            let queue = DispatchQueue(label: "ring.partition.readers", attributes: .concurrent)
            let capacity = emb_ring_buffer_capacity(buf)

            for window in windows {
                group.enter()
                queue.async {
                    let output = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
                    defer { output.deallocate() }

                    while !stop.isSet {
                        let result = emb_ring_buffer_read_range(
                            buf, window.start, window.end, output, capacity)
                        let records = parseRecords(output, result)
                        for i in 0..<records.count {
                            let ts = records[i].timestamp_ns
                            if ts < window.start || ts > window.end {
                                failures.record("partition violation: ts=\(ts) not in [\(window.start), \(window.end)]")
                            }
                        }
                    }
                    group.leave()
                }
            }

            for i in 0..<10 {
                let f: [UInt] = [UInt(i + 1)]
                emb_ring_buffer_write(buf, UInt64(i) * intervalNs, f, 1)
                Thread.sleep(forTimeInterval: 0.001)
            }
            stop.set()
            group.wait()

            assertNoFailures(failures)
        }

        /// Small (1-page) buffer with high-frequency writer forcing wrap-around.
        /// 4+ concurrent readers verify no frame corruption and ascending timestamps.
        func test_smallBuffer_highFrequencyWrapAround_noCorruption() {
            let buf = emb_ring_buffer_create(Int(getpagesize()))!
            defer { emb_ring_buffer_destroy(buf) }

            let writeCount = 500
            let frameCount = 8

            let failures = runWithReaders(
                buf: buf, readerCount: 4,
                validate: { records, fc in
                    // Timestamps must be ascending.
                    if records.count > 1 {
                        for i in 1..<records.count {
                            let prev = records[i - 1].timestamp_ns
                            let cur = records[i].timestamp_ns
                            if cur < prev {
                                fc.record("wrap-around: timestamps went backwards \(prev) → \(cur)")
                            }
                        }
                    }
                    // Frame data must be internally consistent: frame[j] = idx * 10_000 + j + 1.
                    for rec in records {
                        let intervalNs: UInt64 = 1_000
                        let idx = Int(rec.timestamp_ns / intervalNs)
                        let base = UInt(idx) * 10_000
                        for j in 0..<rec.frame_count {
                            let expected = base + UInt(j) + 1
                            if rec.frames[j] != expected {
                                fc.record("wrap-around: ts=\(rec.timestamp_ns) frame[\(j)]: expected \(expected), got \(rec.frames[j])")
                                break
                            }
                        }
                    }
                },
                writerBlock: { _ in
                    for i in 0..<writeCount {
                        let f = self.makeFrames(writeIndex: i, count: frameCount)
                        emb_ring_buffer_write(buf, UInt64(i) * 1_000, f, frameCount)
                        // No sleep. Maximum write pressure to force rapid wrap-around.
                    }
                }
            )

            assertNoFailures(failures)
        }

        /// After the writer stops, 20 concurrent readers must all see identical data.
        func test_afterWriterStops_readsAreStable() {
            let buf = emb_ring_buffer_create(1 * 1024 * 1024)!
            defer { emb_ring_buffer_destroy(buf) }

            for i in 0..<10 {
                let f = makeFrames(writeIndex: i, count: 5)
                emb_ring_buffer_write(buf, UInt64(i + 1) * 100_000_000, f, 5)
            }

            let readerCount = 20
            let lock = NSLock()
            var snapshots = [[UInt64]]()
            let group = DispatchGroup()
            let queue = DispatchQueue(label: "ring.stable.readers", attributes: .concurrent)
            let capacity = emb_ring_buffer_capacity(buf)

            for _ in 0..<readerCount {
                group.enter()
                queue.async {
                    let output = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
                    defer { output.deallocate() }

                    let result = emb_ring_buffer_read_range(buf, 0, UINT64_MAX, output, capacity)
                    let records = parseRecords(output, result)
                    let ts = records.map { $0.timestamp_ns }
                    lock.lock()
                    snapshots.append(ts)
                    lock.unlock()
                    group.leave()
                }
            }
            group.wait()

            let ref = snapshots[0]
            for i in 1..<snapshots.count {
                XCTAssertEqual(
                    snapshots[i], ref,
                    "reader \(i) saw different data than reader 0 after writer stopped")
            }
        }
    }

#endif
