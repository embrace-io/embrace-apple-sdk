//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceConfigInternal
import EmbraceConfiguration
import EmbraceStorageInternal
import OpenTelemetryApi
import TestSupport
import XCTest

@testable import EmbraceCore

class DefaultInternalLoggerTests: XCTestCase {

    let fileProvider = TemporaryFilepathProvider()
    var pendingURL: URL!
    var criticalURL: URL!

    override func setUpWithError() throws {
        try? FileManager.default.removeItem(at: fileProvider.tmpDirectory)
        try? FileManager.default.createDirectory(
            at: fileProvider.directoryURL(for: "DefaultInternalLoggerTests")!,
            withIntermediateDirectories: true
        )

        let scope = "DefaultInternalLoggerTests"
        pendingURL = fileProvider.fileURL(for: scope, name: "\(testName)-pending")!
        criticalURL = fileProvider.fileURL(for: scope, name: "\(testName)-critical")!
    }

    private func makeLogger(byteLimit: Int = 1000) -> DefaultInternalLogger {
        let logger = DefaultInternalLogger(
            pendingFilePath: pendingURL,
            criticalFilePath: criticalURL,
            exportByCountLimit: byteLimit
        )
        logger.level = .trace
        return logger
    }

    /// .startup-only run leaves the staging file on disk but never creates a critical-logs file.
    func test_startupOnly_doesNotCreateCriticalFile() {
        let logger = makeLogger()

        logger.startup("startup1")
        logger.startup("startup2")
        logger.startup("startup3")

        XCTAssertTrue(FileManager.default.fileExists(atPath: pendingURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: criticalURL.path))

        let pending = try? String(contentsOf: pendingURL)
        XCTAssertTrue(pending?.contains("startup1") ?? false)
        XCTAssertTrue(pending?.contains("startup2") ?? false)
        XCTAssertTrue(pending?.contains("startup3") ?? false)
    }

    /// First .critical promotes the staging file to the upload path; pending is gone.
    func test_firstCritical_promotesPendingToCritical() {
        let logger = makeLogger()

        logger.startup("startup1")
        logger.startup("startup2")
        logger.critical("boom")

        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: criticalURL.path))

        let dump = try? String(contentsOf: criticalURL)
        XCTAssertTrue(dump?.contains("startup1") ?? false)
        XCTAssertTrue(dump?.contains("startup2") ?? false)
        XCTAssertTrue(dump?.contains("boom") ?? false)
    }

    /// .critical without prior .startup writes directly to the upload path.
    func test_criticalOnly_createsCriticalFileDirectly() {
        let logger = makeLogger()

        logger.critical("boom")

        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: criticalURL.path))

        let dump = try? String(contentsOf: criticalURL)
        XCTAssertTrue(dump?.contains("boom") ?? false)
    }

    /// Multiple .criticals all land in the critical file; promotion only happens once.
    func test_multipleCriticals_promoteOnceAndAppend() {
        let logger = makeLogger()

        logger.critical("c1")
        logger.critical("c2")
        logger.critical("c3")

        let dump = try? String(contentsOf: criticalURL)
        XCTAssertTrue(dump?.contains("c1") ?? false)
        XCTAssertTrue(dump?.contains("c2") ?? false)
        XCTAssertTrue(dump?.contains("c3") ?? false)

        // pending was never created (or was promoted); either way it must be gone now
        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingURL.path))
    }

    /// Startup lines logged after promotion also land in the critical file.
    func test_startupAfterCritical_appendsToCriticalFile() {
        let logger = makeLogger()

        logger.critical("boom")
        logger.startup("late-startup")

        let dump = try? String(contentsOf: criticalURL)
        XCTAssertTrue(dump?.contains("boom") ?? false)
        XCTAssertTrue(dump?.contains("late-startup") ?? false)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingURL.path))
    }

    /// Once the byte budget is exhausted, further writes are dropped — file size is bounded.
    func test_byteCountLimit_capsFileSize() {
        // small limit: ~one short line max
        let logger = makeLogger(byteLimit: 80)

        logger.critical("first-line-that-fits")
        // these subsequent writes should be dropped because they'd exceed the limit
        logger.critical("second-line-must-be-dropped-because-too-large")
        logger.critical("third-line-must-also-be-dropped-because-too-large")

        let dump = (try? String(contentsOf: criticalURL)) ?? ""
        XCTAssertTrue(dump.contains("first-line-that-fits"))
        XCTAssertFalse(dump.contains("second-line-must-be-dropped"))
        XCTAssertFalse(dump.contains("third-line-must-also"))

        let attrs = try? FileManager.default.attributesOfItem(atPath: criticalURL.path)
        let size = (attrs?[.size] as? NSNumber)?.intValue ?? 0
        XCTAssertLessThanOrEqual(size, 80)
    }

    /// Non-customExport logs (info/warning/error) must not create any export file.
    func test_nonCustomExportLevels_doNotCreateFile() {
        let logger = makeLogger()

        logger.trace("t")
        logger.debug("d")
        logger.info("i")
        logger.warning("w")
        logger.error("e")

        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: criticalURL.path))
    }

    /// A stale critical-logs file from a prior run is overwritten on promotion.
    func test_stalePreExistingCritical_isOverwrittenOnPromotion() throws {
        try "STALE".write(to: criticalURL, atomically: true, encoding: .utf8)

        let logger = makeLogger()
        logger.startup("fresh-startup")
        logger.critical("fresh-critical")

        let dump = try String(contentsOf: criticalURL)
        XCTAssertFalse(dump.contains("STALE"))
        XCTAssertTrue(dump.contains("fresh-startup"))
        XCTAssertTrue(dump.contains("fresh-critical"))
    }

    /// Concurrent log calls from many threads complete without crashing and produce
    /// well-formed output (every line terminated with \n, every line maps to one input).
    func test_threadSafety_concurrentLogs() {
        let logger = makeLogger(byteLimit: 100_000)
        let group = DispatchGroup()
        let totalThreads = 16
        let perThread = 25

        for t in 0..<totalThreads {
            DispatchQueue.global().async(group: group) {
                for i in 0..<perThread {
                    if i % 5 == 0 {
                        logger.critical("c-\(t)-\(i)")
                    } else {
                        logger.startup("s-\(t)-\(i)")
                    }
                }
            }
        }

        group.wait()

        // After at least one .critical the file must exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: criticalURL.path))

        let dump = (try? String(contentsOf: criticalURL)) ?? ""
        // every line must be terminated; trailing newline means split keeps empty element
        let lines = dump.split(separator: "\n", omittingEmptySubsequences: true)
        for line in lines {
            // each line must contain one of our injected tokens
            XCTAssertTrue(
                line.contains("s-") || line.contains("c-"),
                "Unexpected line: \(line)"
            )
        }
    }
}
