//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import EmbraceCommon

@testable import EmbraceIO

final class EmbraceSetupDataCollectionTests: XCTestCase {

    class ExampleCollector: Collector {

        var didStart = false
        var didStop = false
        var available = true

        func setup(context: EmbraceCommon.CollectorContext) { }

        func start() {
            didStart = true
        }

        func stop() {
            didStop = true
        }
    }

    class ExampleInstalledCollector: InstalledCollector {
        var didStart = false
        var didStop = false
        var available = true

        var didInstall = false
        var didShutdown = false

        func start() {
            didStart = true
        }

        func stop() {
            didStop = true
        }

        func install(context: EmbraceCommon.CollectorContext) {
            didInstall = true
        }

        func uninstall() {
            didShutdown = true
        }
    }

    func test_EmbraceSetup_passesCollectorsToDataCollection() throws {
        try Embrace.setup(options: .init(appId: "myAPP", collectors: [
            ExampleCollector(),
            ExampleInstalledCollector()
        ]))

        let collectors = Embrace.client!.collection.collectors
        XCTAssertTrue(collectors.contains { $0 is ExampleCollector })
        XCTAssertTrue(collectors.contains { $0 is ExampleInstalledCollector })
    }

}
