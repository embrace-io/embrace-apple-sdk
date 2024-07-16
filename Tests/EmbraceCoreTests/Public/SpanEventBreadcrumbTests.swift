//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import EmbraceOTelInternal
@testable import EmbraceCore

class SpanEventBreadcrumbTests: XCTestCase {
    func test_breadcrumbWithMessage_forwardsMessageToABreadcrumbInstance() throws {
        let spanEvent: SpanEvent = .breadcrumb("a message!")
        let breadcrumb = try XCTUnwrap(spanEvent as? Breadcrumb)
        XCTAssertEqual(breadcrumb.attributes["message"], .string("a message!"))
    }

    func test_breadcrumbWithProperties_forwardsPropertiesAsBreadcrumbAttributesWithoutRemovingDefault() throws {
        let spanEvent: SpanEvent = .breadcrumb(.random(), properties: [
            "first_key": "a_value",
            "second_key": "another_value"
        ])
        let breadcrumb = try XCTUnwrap(spanEvent as? Breadcrumb)
        XCTAssertEqual(breadcrumb.attributes["first_key"], .string("a_value"))
        XCTAssertEqual(breadcrumb.attributes["second_key"], .string("another_value"))
        XCTAssertNotNil(breadcrumb.attributes["message"])
        XCTAssertNotNil(breadcrumb.attributes["emb.type"])
    }
}
