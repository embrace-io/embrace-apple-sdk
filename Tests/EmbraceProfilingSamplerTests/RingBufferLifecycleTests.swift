//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)

    import Darwin
    import EmbraceProfilingSampler
    import XCTest

    /// Tests for `emb_ring_buffer_create` / `emb_ring_buffer_destroy` and the
    /// VM double-mapping that eliminates wrap-around handling.
    final class RingBufferLifecycleTests: XCTestCase {

        // MARK: - Create / destroy lifecycle

        func test_create_returnsNonNil_withValidParams() {
            let buf = emb_ring_buffer_create(1024 * 1024)
            XCTAssertNotNil(buf)
            emb_ring_buffer_destroy(buf)
        }

        func test_create_capacityIsPageAligned() {
            // Requesting 1 byte should yield at least one full page.
            let buf = emb_ring_buffer_create(1)
            guard let buf = buf else {
                XCTFail("emb_ring_buffer_create should succeed")
                return
            }
            defer { emb_ring_buffer_destroy(buf) }

            let pageSize = Int(getpagesize())
            XCTAssertGreaterThanOrEqual(
                buf.pointee.capacity, pageSize,
                "capacity must be at least one page")
            XCTAssertEqual(
                buf.pointee.capacity % pageSize, 0,
                "capacity must be page-aligned")
        }

        func test_create_dataPointerIsNonNil() {
            let buf = emb_ring_buffer_create(1024 * 1024)
            guard let buf = buf else {
                XCTFail("emb_ring_buffer_create should succeed")
                return
            }
            defer { emb_ring_buffer_destroy(buf) }

            XCTAssertNotNil(buf.pointee.data)
        }

        func test_destroy_withNil_doesNotCrash() {
            // emb_ring_buffer_destroy(NULL) must be a no-op.
            emb_ring_buffer_destroy(nil)
        }

        func test_create_canBeCalledMultipleTimes() {
            for _ in 0..<4 {
                let buf = emb_ring_buffer_create(512 * 1024)
                XCTAssertNotNil(buf)
                emb_ring_buffer_destroy(buf)
            }
        }

        // MARK: - VM double-mapping

        /// Writes 8 bytes straddling the end of the first mapping and verifies
        /// that the 4 bytes written into the second mapping ([capacity, capacity+3])
        /// are immediately visible at the start of the first mapping ([0, 3]).
        func test_doubleMapping_writeStraddle_wrapsToStart() {
            // Use a small capacity_bytes; it will be rounded up to one page.
            let buf = emb_ring_buffer_create(1)
            guard let buf = buf else {
                XCTFail("emb_ring_buffer_create should succeed")
                return
            }
            defer { emb_ring_buffer_destroy(buf) }

            let capacity = Int(buf.pointee.capacity)
            let data = buf.pointee.data!

            // Write 8 bytes starting 4 bytes before the end of the first mapping.
            // Bytes at offsets [capacity, capacity+3] land in the second mapping.
            // Because both halves share physical pages, those bytes must also
            // appear at offsets [0, 3] in the first mapping.
            let writeStart = capacity - 4
            for i in 0..<8 {
                data[writeStart + i] = UInt8(i + 1)  // values 1 … 8
            }

            // Bytes written via the second mapping (offsets capacity … capacity+3)
            // should be visible at the mirror offsets 0 … 3.
            for i in 0..<4 {
                XCTAssertEqual(
                    data[i], UInt8(i + 5),
                    "double-mapping wrap: data[\(i)] expected \(i + 5), got \(data[i])")
            }
        }

        /// Verifies the mirror in the other direction: writing to the start of the
        /// first mapping is immediately visible in the second mapping.
        func test_doubleMapping_writeAtStart_visibleBeyondCapacity() {
            let buf = emb_ring_buffer_create(1)
            guard let buf = buf else {
                XCTFail("emb_ring_buffer_create should succeed")
                return
            }
            defer { emb_ring_buffer_destroy(buf) }

            let capacity = Int(buf.pointee.capacity)
            let data = buf.pointee.data!

            // Write 4 bytes at the start of the first mapping.
            let pattern: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
            for (i, byte) in pattern.enumerated() {
                data[i] = byte
            }

            // The same bytes must appear at capacity … capacity+3 (second mapping).
            for (i, expected) in pattern.enumerated() {
                XCTAssertEqual(
                    data[capacity + i], expected,
                    "second mapping mirror: data[\(capacity + i)] expected 0x\(String(expected, radix: 16)), got 0x\(String(data[capacity + i], radix: 16))")
            }
        }
    }

#endif
