//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)

import EmbraceProfilingSampler
import Foundation

/// Decoded ring buffer record for use in tests.
struct TestRecord {
    let timestamp_ns: UInt64
    let frame_count: Int
    let frames: [UInt]
}

/// Read matching records from a ring buffer into Swift-friendly structs.
///
/// Allocates a temporary output buffer of `capacity` bytes, reads into it,
/// parses the results, and deallocates.
func testReadRange(
    _ buf: UnsafeMutablePointer<emb_ring_buffer_t>,
    _ startNs: UInt64,
    _ endNs: UInt64
) -> [TestRecord] {
    let capacity = emb_ring_buffer_capacity(buf)
    let output = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
    defer { output.deallocate() }

    let result = emb_ring_buffer_read_range(buf, startNs, endNs, output, capacity)
    return parseRecords(output, result)
}

/// Parse records from a raw output buffer filled by `emb_ring_buffer_read_range`.
func parseRecords(
    _ output: UnsafeMutablePointer<UInt8>,
    _ result: emb_ring_read_result_t
) -> [TestRecord] {
    let headerSize = MemoryLayout<emb_ring_record_header_t>.size
    let validEnd = Int(result.records_offset) + Int(result.total_bytes)

    var records: [TestRecord] = []
    var offset = Int(result.records_offset)
    for _ in 0..<result.record_count {
        guard offset + headerSize <= validEnd else { break }

        let hdr = (output + offset).withMemoryRebound(
            to: emb_ring_record_header_t.self, capacity: 1
        ) { $0.pointee }

        let fc = Int(hdr.frame_count)
        let recordSize = Int(emb_ring_record_size(hdr.frame_count))
        guard offset + recordSize <= validEnd else { break }

        var frames: [UInt] = []
        if fc > 0 {
            let framesStart = output + offset + headerSize
            framesStart.withMemoryRebound(to: UInt.self, capacity: fc) { ptr in
                for j in 0..<fc {
                    frames.append(ptr[j])
                }
            }
        }

        records.append(TestRecord(
            timestamp_ns: hdr.timestamp_ns,
            frame_count: fc,
            frames: frames
        ))

        offset += recordSize
    }
    return records
}

/// Wait for the C sampler to stop, polling at 1ms intervals.
func waitForSamplerToStop(timeout: TimeInterval = 2.0) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while emb_sampler_is_active() {
        if Date() >= deadline { return false }
        Thread.sleep(forTimeInterval: 0.001)
    }
    return true
}

/// Wait for the C sampler to reach RUNNING state, polling at 1ms intervals.
func waitForSamplerRunning(timeout: TimeInterval = 2.0) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while emb_sampler_get_state() != EMB_SAMPLER_RUNNING {
        if Date() >= deadline { return false }
        Thread.sleep(forTimeInterval: 0.001)
    }
    return true
}

#endif
