//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import Foundation
import XCTest

@testable import EmbraceCore
@testable import EmbraceIO

/// A `Symbolicator` that resolves every address to a frame carrying a known, full-length Mach-O UUID.
///
/// The UUID is the value the *real* symbolicator would already have produced (via
/// `NSUUID(uuidBytes:).uuidString` from KSCrash's raw `uuid_t`). It is deliberately a full 36-char
/// UUID string so the test can prove it survives `EmbraceBacktrace.symbolicated()` unchanged.
private final class FixedUUIDSymbolicator: NSObject, Symbolicator {
    static let fullUUID = "F70C76E3-1352-3A80-A123-456789ABCDEF"  // 36 chars

    func resolve(address: FrameAddress) -> SymbolicatedFrame? {
        SymbolicatedFrame(
            returnAddress: address,
            callInstruction: address,
            symbolAddress: 0x1000,
            symbolName: "emb_test_symbol",
            imageName: "TestImage",
            imageUUID: Self.fullUUID,
            imageAddress: 0x1000,
            imageSize: 0x2000
        )
    }
}

/// Regression guard for a UUID-truncation bug in `EmbraceBacktrace.symbolicated()`.
///
/// The `SymbolicatedFrame.imageUUID` handed back by the symbolicator is *already* the full Mach-O
/// UUID **string**. A previous version re-ran it through `NSUUID(uuidBytes:)`, which reinterprets the
/// string's first 16 UTF-8 bytes as a raw `uuid_t` — silently truncating the UUID to its first 16
/// characters (e.g. `F70C76E3-1352-3A80-…` collapsed to the `uuidString` of "F70C76E3-1352-3A"). That
/// broke server-side symbolication of system frames in hang/backtrace payloads, where the full image
/// UUID is what matches the symbol file. These tests fail loudly if that reinterpretation returns.
final class BacktraceImageUUIDTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // The EmbraceCore designated initializer is the documented way to inject a custom symbolicator.
        // `symbolicated()` reads `Embrace.client?.options.symbolicator`, so it must be set on the client.
        let options = Embrace.Options(
            appId: "myApp",
            captureServices: [],
            crashReporter: nil,
            symbolicator: FixedUUIDSymbolicator()
        )
        _ = try? Embrace.setup(options: options).start()
    }

    override func tearDown() {
        _ = try? Embrace.client?.stop()
        Embrace.client = nil
        super.tearDown()
    }

    /// The exact output the truncation bug produced: the `uuidString` of the first 16 UTF-8 bytes of
    /// the UUID string. Kept as an explicit fixture so a reintroduced bug is matched precisely.
    private var knownTruncation: String {
        NSUUID(uuidBytes: Array(FixedUUIDSymbolicator.fullUUID.utf8)).uuidString
    }

    func test_symbolicatedFrame_preservesFullImageUUID() throws {
        let thread = EmbraceBacktraceThread(
            index: 0,
            callstack: .init(addresses: [0xABCD_EF00], count: 1)
        )

        let image = try XCTUnwrap(
            thread.frames(symbolicated: true).first?.image,
            "frame was not symbolicated (no image); check that the mock symbolicator is wired up"
        )

        XCTAssertEqual(
            image.uuid, FixedUUIDSymbolicator.fullUUID,
            "image UUID was corrupted during symbolication"
        )
        XCTAssertEqual(
            image.uuid.count, 36,
            "expected a full 36-char Mach-O UUID, got \(image.uuid.count) chars: \(image.uuid)"
        )
        XCTAssertNotEqual(
            image.uuid, knownTruncation,
            "image UUID matches the known truncation-bug output — the UUID string is being "
                + "reinterpreted as raw uuid_t bytes again in EmbraceBacktrace.symbolicated()"
        )
    }

    /// The value must also survive into the processed-frame dictionary (`u` key) that is serialized
    /// into the hang/crash payload — the layer where the corruption was originally observed.
    func test_processedFrame_carriesFullImageUUID() throws {
        let thread = EmbraceBacktraceThread(
            index: 0,
            callstack: .init(addresses: [0xABCD_EF10], count: 1)
        )

        let frame = try XCTUnwrap(thread.frames(symbolicated: true).first)
        let processed = try XCTUnwrap(
            frame.asProcessedFrame(),
            "frame did not produce a processed dictionary (image or symbol was nil)"
        )
        let uuid = try XCTUnwrap(
            processed[EmbraceBacktraceFrame.moduleUUIDKey] as? String,
            "processed frame is missing the UUID (`u`) key"
        )

        XCTAssertEqual(uuid, FixedUUIDSymbolicator.fullUUID)
        XCTAssertEqual(uuid.count, 36, "payload `u` was truncated: \(uuid)")
    }
}
