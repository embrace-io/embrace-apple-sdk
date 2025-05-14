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

@available(iOS 15.0, *)
class DefaultInternalLoggerTests: XCTestCase {

    let fileProvider = TemporaryFilepathProvider()
    var fileUrl: URL!

    override func setUpWithError() throws {
        try? FileManager.default.removeItem(at: fileProvider.tmpDirectory)

        fileUrl = fileProvider.fileURL(for: "DefaultInternalLoggerTests", name: "file")!
        try? FileManager.default.createDirectory(at: fileProvider.directoryURL(for: "DefaultInternalLoggerTests")!, withIntermediateDirectories: true)
    }

    func test_logger() throws {
        // given a logger
        let logger = DefaultInternalLogger(exportFilePath: fileUrl)
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
            .filter { $0.subsystem == "com.embrace.logger" && $0.category == "custom-export" }
            .map { $0.composedMessage }

        XCTAssert(customExportEntries.contains("startup"))
        XCTAssert(customExportEntries.contains("critical"))

        // then the right logs are exported to disk
        let logs = try String(contentsOf: fileUrl)
        XCTAssert(logs.contains("startup"))
        XCTAssert(logs.contains("critical"))
    }
}
