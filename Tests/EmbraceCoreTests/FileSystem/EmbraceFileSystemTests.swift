//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore

class EmbraceFileSystemTests: XCTestCase {
    func test_oldVersionsURLs() throws {

        #if os(tvOS)
            let directory = FileManager.SearchPathDirectory.cachesDirectory
        #else
            let directory = FileManager.SearchPathDirectory.applicationSupportDirectory
        #endif

        let baseURL = try FileManager.default.url(
            for: directory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let urls = EmbraceFileSystem.oldVersionsDirectories().map { $0.path }

        for i in 1...EmbraceFileSystem.version - 1 {
            let components = [EmbraceFileSystem.rootDirectoryName, "v\(i)"]
            let url = baseURL.appendingPathComponent(components.joined(separator: "/"))
            XCTAssert(urls.contains(url.path))
        }
    }

    func test_typedDirectoryURLs_useVersionedPartitionedLayout() throws {
        let partition = "myPartition"
        // reference the source constant for the version segment so a version bump is a single change there
        let versioned = "io.embrace.data/\(EmbraceFileSystem.versionDirectoryName)/\(partition)"

        let storage = try XCTUnwrap(EmbraceFileSystem.storageDirectoryURL(partitionId: partition))
        XCTAssertTrue(storage.path.hasSuffix("\(versioned)/storage"))

        let uploads = try XCTUnwrap(EmbraceFileSystem.uploadsDirectoryPath(partitionIdentifier: partition))
        XCTAssertTrue(uploads.path.hasSuffix("\(versioned)/uploads"))

        let capture = try XCTUnwrap(EmbraceFileSystem.captureDirectoryURL(partitionIdentifier: partition))
        XCTAssertTrue(capture.path.hasSuffix("\(versioned)/capture"))

        let config = try XCTUnwrap(EmbraceFileSystem.configDirectoryURL(partitionIdentifier: partition))
        XCTAssertTrue(config.path.hasSuffix("\(versioned)/config"))
    }

    func test_rootLevelFileURLs_liveAtRoot_notUnderVersionDirectory() throws {
        // device-id, critical-logs and pending-logs are intentionally at the root, NOT under the
        // version directory; putting them there would break crash/log promotion across SDK upgrades.
        let versionSegment = "/\(EmbraceFileSystem.versionDirectoryName)/"

        let deviceId = try XCTUnwrap(EmbraceFileSystem.deviceIdURL)
        XCTAssertTrue(deviceId.path.hasSuffix("io.embrace.data/device-identifier"))
        XCTAssertFalse(deviceId.path.contains(versionSegment))

        let critical = try XCTUnwrap(EmbraceFileSystem.criticalLogsURL)
        XCTAssertTrue(critical.path.hasSuffix("io.embrace.data/critical-logs"))
        XCTAssertFalse(critical.path.contains(versionSegment))

        let pending = try XCTUnwrap(EmbraceFileSystem.pendingLogsURL)
        XCTAssertTrue(pending.path.hasSuffix("io.embrace.data/pending-logs"))
        XCTAssertFalse(pending.path.contains(versionSegment))
    }
}
