//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore

class EmbraceFileSystemTests: XCTestCase {
    func test_oldVersionsURLs() throws {
        let baseURL = try FileManager.default.url(
            for: FileManager.SearchPathDirectory.applicationSupportDirectory,
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
}
