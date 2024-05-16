//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceStorage

final class Migrations_CurrentTests: XCTestCase {

    func test_current_returnsMigrationsWithIdentifiersInCorrectOrder() throws {
        let migrations: [Migration] = .current
        let identifiers = migrations.map(\.identifier)

        XCTAssertEqual(migrations.count, 4)
        XCTAssertEqual(identifiers, [
            // add identifiers here
            "CreateSpanRecordTable",
            "CreateSessionRecordTable",
            "CreateMetadataRecordTable",
            "CreateLogRecordTable"
        ])
    }

}
