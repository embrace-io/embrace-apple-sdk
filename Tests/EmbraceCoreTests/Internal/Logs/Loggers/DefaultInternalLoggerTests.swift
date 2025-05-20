//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
import TestSupport
import EmbraceStorageInternal
import EmbraceConfigInternal
import EmbraceConfiguration
import OpenTelemetryApi
import EmbraceCommonInternal
import OSLog

@available(iOS 15.0, tvOS 15.0, *)
class DefaultInternalLoggerTests: XCTestCase {

    let fileProvider = TemporaryFilepathProvider()
    var fileUrl: URL!

    override func setUpWithError() throws {
        try? FileManager.default.removeItem(at: fileProvider.tmpDirectory)

        fileUrl = fileProvider.fileURL(for: "DefaultInternalLoggerTests", name: "file")!
        try? FileManager.default.createDirectory(at: fileProvider.directoryURL(for: "DefaultInternalLoggerTests")!, withIntermediateDirectories: true)
    }

    func test_categories() throws {
        // given a logger
        let category = "custom-export-\(testName)-\(UUID().withoutHyphen)"
        let logger = DefaultInternalLogger(exportFilePath: fileUrl, exportCategory: category)
        logger.level = .trace

        // when creating logs
        logger.trace("trace")
        logger.debug("debug")
        logger.info("info")
        logger.warning("warning")
        logger.error("error")
        logger.startup("startup")
        logger.critical("critical")

        // then they are sent to the correct internal OSLog logger
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let position = store.position(timeIntervalSinceLatestBoot: 0)

        let defaultEntries: [String] = try store
            .getEntries(at: position)
            .compactMap { $0 as? OSLogEntryLog }
            .filter { $0.subsystem == "com.embrace.logger" && $0.category == "internal" }
            .map { $0.composedMessage }

        XCTAssert(defaultEntries.contains("trace"))
        XCTAssert(defaultEntries.contains("debug"))
        XCTAssert(defaultEntries.contains("info"))
        XCTAssert(defaultEntries.contains("warning"))
        XCTAssert(defaultEntries.contains("error"))

        let customExportEntries: [String] = try store
            .getEntries(at: position)
            .compactMap { $0 as? OSLogEntryLog }
            .filter { $0.subsystem == "com.embrace.logger" && $0.category == category }
            .map { $0.composedMessage }

        XCTAssertEqual(customExportEntries.count, 2)
        XCTAssert(customExportEntries.contains("startup"))
        XCTAssert(customExportEntries.contains("critical"))
    }

    func test_export_withCriticalLogs() throws {
        // given a logger
        let logger = DefaultInternalLogger(
            exportFilePath: fileUrl,
            exportCategory: "custom-export-\(testName)-\(UUID().withoutHyphen)"
        )
        logger.level = .trace

        // when doing custom exportable logs without 0 critical logs
        logger.startup("startup1")
        logger.startup("startup2")
        logger.startup("startup3")
        logger.startup("startup4")
        logger.startup("startup5")
        logger.critical("critical")

        wait(timeout: .veryLongTimeout) {
            // then the exported file has the correct values
            guard let log = try? String(contentsOf: self.fileUrl) else {
                return false
            }

            return log.contains("startup1") &&
                   log.contains("startup2") &&
                   log.contains("startup3") &&
                   log.contains("startup4") &&
                   log.contains("startup5") &&
                   log.contains("critical")
        }
    }

    func test_export_withoutCriticalLog() {
        // given a logger
        let logger = DefaultInternalLogger(
            exportFilePath: fileUrl,
            exportCategory: "custom-export-\(testName)-\(UUID().withoutHyphen)"
        )
        logger.level = .trace

        // when doing custom exportable logs without 0 critical logs
        logger.startup("startup1")
        logger.startup("startup2")
        logger.startup("startup3")
        logger.startup("startup4")
        logger.startup("startup5")

        wait(delay: .defaultTimeout)

        // then no custom export file is created
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileUrl.path))
    }

    func test_multiple_exports() {
        // given a logger
        let logger = DefaultInternalLogger(
            exportFilePath: fileUrl,
            exportCategory: "custom-export-\(testName)-\(UUID().withoutHyphen)"
        )
        logger.level = .trace

        // when creating a critical log
        logger.critical("critical1")

        wait(timeout: .veryLongTimeout) {
            // then the exported file has the correct values
            guard let log = try? String(contentsOf: self.fileUrl) else {
                return false
            }

            return log.contains("critical1")
        }

        // when doing another critical log
        logger.critical("critical2")

        wait(timeout: .veryLongTimeout) {
            // then the exported file has the correct values
            guard let log = try? String(contentsOf: self.fileUrl) else {
                return false
            }

            return log.contains("critical1") && log.contains("critical2")
        }

        // when doing another critical log
        logger.critical("critical3")

        wait(timeout: .veryLongTimeout) {
            // then the exported file has the correct values
            guard let log = try? String(contentsOf: self.fileUrl) else {
                return false
            }

            return log.contains("critical1") && log.contains("critical2") && log.contains("critical3")
        }
    }
}
