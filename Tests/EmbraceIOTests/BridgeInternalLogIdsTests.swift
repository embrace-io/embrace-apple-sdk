//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceCommonInternal
@testable import EmbraceCore
@testable import EmbraceIO
@testable import EmbraceOTelBridge

/// Covers the lifetime of the IDs the OTel bridge uses to recognize its own outbound logs.
///
/// Those IDs are only needed while the log is being emitted: the OTel log processor chain runs
/// synchronously inside `emit()`. This test drives the full public logging path to confirm that
/// nothing is retained afterwards, and that scoping the IDs to the emit window did not break the
/// deduplication they exist for — each log must still reach the pipeline exactly once.
final class BridgeInternalLogIdsTests: XCTestCase {

    private let logCount = 10
    private var exporter: ThreadSafeLogExporter!

    override func setUpWithError() throws {
        try super.setUpWithError()

        exporter = ThreadSafeLogExporter()
        try EmbraceIO.start(
            options: EmbraceIO.Options.withLocalConfiguration(
                captureServices: CaptureServicesOptionsBuilder().build(),
                crashReporter: .none,
                otel: EmbraceIO.OTelOptions(logExporters: [exporter])
            )
        )
    }

    override func tearDownWithError() throws {
        try? EmbraceIO.shared.stop()
        Embrace.client = nil
        exporter = nil
        try super.tearDownWithError()
    }

    func test_repeatedLogs_leaveNoInternalLogIdsBehind_andAreExportedOnce() throws {
        for i in 0..<logCount {
            EmbraceIO.shared.log("bridge-log-\(i)", severity: .info)
        }

        wait(timeout: .veryLongTimeout) { self.exportedBodies().count >= self.logCount }

        // Every log made it through the pipeline exactly once.
        let bodies = exportedBodies()
        for i in 0..<logCount {
            XCTAssertEqual(bodies.filter { $0 == "bridge-log-\(i)" }.count, 1)
        }

        // ...and the bridge kept none of their IDs.
        let bridge = try XCTUnwrap(Embrace.client?.otel.bridge as? EmbraceOTelBridge)
        XCTAssertTrue(bridge.inFlightInternalLogIds.isEmpty)
    }

    private func exportedBodies() -> [String] {
        exporter.exportedLogs.compactMap {
            guard case let .string(body) = $0.body else { return nil }
            return body.hasPrefix("bridge-log-") ? body : nil
        }
    }
}

class ThreadSafeLogExporter: LogRecordExporter {
    private let logs = EmbraceMutex([ReadableLogRecord]())
    var exportedLogs: [ReadableLogRecord] { logs.withLock { $0 } }

    func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
        logs.withLock { $0.append(contentsOf: logRecords) }
        return .success
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult { .success }
    func shutdown(explicitTimeout: TimeInterval?) {}
}
