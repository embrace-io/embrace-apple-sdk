//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import EmbraceSemantics
@testable import EmbraceCore

class SpanEventBreadcrumbTests: XCTestCase {
    func test_breadcrumbWithMessage_forwardsMessageToABreadcrumbInstance() throws {
        let spanEvent: EmbraceSpanEvent = .breadcrumb("a message!")
        let breadcrumb = try XCTUnwrap(spanEvent as? Breadcrumb)
        XCTAssertEqual(breadcrumb.attributes["message"], "a message!")
    }

    func test_breadcrumbWithProperties_forwardsPropertiesAsBreadcrumbAttributesWithoutRemovingDefault() throws {
        let spanEvent: EmbraceSpanEvent = .breadcrumb(
            .random(),
            attributes: [
                "first_key": "a_value",
                "second_key": "another_value"
            ]
        )
        
        let breadcrumb = try XCTUnwrap(spanEvent as? Breadcrumb)
        XCTAssertEqual(breadcrumb.attributes["first_key"], "a_value")
        XCTAssertEqual(breadcrumb.attributes["second_key"], "another_value")
        XCTAssertNotNil(breadcrumb.attributes["message"])
        XCTAssertNotNil(breadcrumb.attributes["emb.type"])
    }
}
