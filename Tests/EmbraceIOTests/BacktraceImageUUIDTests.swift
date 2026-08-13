//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceKSCrashBacktraceSupport
import Foundation
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceIO

/// Regression guard for a UUID-truncation bug in `EmbraceBacktrace.symbolicated()`.
///
/// The `SymbolicatedFrame.imageUUID` produced by `KSCrashBacktracing.resolve(address:)` is *already*
/// the full Mach-O UUID **string** (it converts KSCrash's raw `uuid_t` via `NSUUID(uuidBytes:)`
/// internally). A previous version of `symbolicated()` re-ran that string through
/// `NSUUID(uuidBytes:)`, which reinterprets the string's first 16 UTF-8 bytes as a raw `uuid_t` —
/// silently replacing the real UUID with one derived from its own ASCII characters. That broke
/// server-side symbolication of system frames in hang/backtrace payloads, where the full image UUID
/// is what matches the symbol file. These tests fail loudly if that reinterpretation returns.
///
/// There is no symbolicator injection point in this SDK version — `symbolicated()` always uses
/// `KSCrashBacktracing` — so the resolver itself is the oracle: whatever UUID it reports for an
/// address must arrive in the frame, and in the payload, byte-for-byte unchanged.
final class BacktraceImageUUIDTests: XCTestCase {

    /// A real return address from this process, together with the UUID the resolver reports for it.
    /// Real addresses (rather than a synthetic one) are required here: only an address inside a
    /// loaded image resolves to an image at all.
    private func addressWithResolvedUUID() throws -> (address: UInt, uuid: String) {
        let backtracer = KSCrashBacktracing()
        let candidates = Thread.callStackReturnAddresses.compactMap { $0 as? UInt }
        XCTAssertFalse(candidates.isEmpty, "the current call stack produced no return addresses")

        // `resolve(address:)` is handed the same address `symbolicated()` passes it, so the UUID
        // compared below is exactly what the pipeline had to work with.
        let resolved: (address: UInt, uuid: String)? =
            candidates.lazy.compactMap { address in
                guard let frame = backtracer.resolve(address: address),
                    let uuid = frame.imageUUID,
                    !uuid.isEmpty
                else { return nil }
                return (address, uuid)
            }.first

        // A test process always has resolvable frames on its own stack, so an empty result means
        // symbolication itself is broken. That's a failure, not something to skip past — skipping here
        // would let a process-wide symbolication regression land as a green build.
        return try XCTUnwrap(
            resolved,
            "no address in the current call stack resolved to a Mach-O image — symbolication is broken")
    }

    /// The output the truncation bug produced for a given real UUID: the `uuidString` of the first 16
    /// UTF-8 bytes of the UUID string itself. Derived from the real value so a reintroduced bug is
    /// matched precisely rather than approximately.
    private func knownTruncation(of uuid: String) -> String {
        NSUUID(uuidBytes: Array(uuid.utf8)).uuidString
    }

    func test_symbolicatedFrame_preservesFullImageUUID() throws {
        // ksbic_init (KSCrash binary-image cache) is not safe under sanitizer instrumentation:
        // TSan aborts; ASan deadlocks until the job cap fires. Symbolication is required here.
        try XCTSkipIfSanitizing("KSCrash symbolication is incompatible with sanitizer instrumentation")

        let (address, expectedUUID) = try addressWithResolvedUUID()
        let thread = EmbraceBacktraceThread(index: 0, callstack: .init(addresses: [address], count: 1))

        let image = try XCTUnwrap(
            thread.frames(symbolicated: true).first?.image,
            "frame was not symbolicated (no image)"
        )

        XCTAssertEqual(
            image.uuid, expectedUUID,
            "image UUID was corrupted during symbolication"
        )
        XCTAssertEqual(
            image.uuid.count, 36,
            "expected a full 36-char Mach-O UUID, got \(image.uuid.count) chars: \(image.uuid)"
        )
        XCTAssertNotEqual(
            image.uuid, knownTruncation(of: expectedUUID),
            "image UUID matches the known truncation-bug output — the UUID string is being "
                + "reinterpreted as raw uuid_t bytes again in EmbraceBacktrace.symbolicated()"
        )
    }

    /// The value must also survive into the processed-frame dictionary (`u` key) that is serialized
    /// into the hang/crash payload — the layer where the corruption was originally observed.
    func test_processedFrame_carriesFullImageUUID() throws {
        try XCTSkipIfSanitizing("KSCrash symbolication is incompatible with sanitizer instrumentation")

        let (address, expectedUUID) = try addressWithResolvedUUID()
        let thread = EmbraceBacktraceThread(index: 0, callstack: .init(addresses: [address], count: 1))

        let frame = try XCTUnwrap(thread.frames(symbolicated: true).first)
        let processed = try XCTUnwrap(
            frame.asProcessedFrame(),
            "frame did not produce a processed dictionary (image or symbol was nil)"
        )
        let uuid = try XCTUnwrap(
            processed[EmbraceBacktraceFrame.moduleUUIDKey] as? String,
            "processed frame is missing the UUID (`u`) key"
        )

        XCTAssertEqual(uuid, expectedUUID)
        XCTAssertEqual(uuid.count, 36, "payload `u` was truncated: \(uuid)")
        XCTAssertNotEqual(uuid, knownTruncation(of: expectedUUID))
    }
}
