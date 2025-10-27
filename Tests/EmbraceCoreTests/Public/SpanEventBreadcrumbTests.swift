//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceOTelInternal
import XCTest

@testable import EmbraceCore

class SpanEventBreadcrumbTests: XCTestCase {
    @available(*, deprecated)
    func test_breadcrumbWithMessage_forwardsMessageToABreadcrumbInstance() throws {
        let spanEvent: SpanEvent = .breadcrumb("a message!")
        let breadcrumb = try XCTUnwrap(spanEvent as? Breadcrumb)
        XCTAssertEqual(breadcrumb.attributes["message"], .string("a message!"))
    }

    @available(*, deprecated)
    func test_breadcrumbDeprecatedWithProperties_forwardsPropertiesAsBreadcrumbAttributesWithoutRemovingDefault() throws {
        let spanEvent: SpanEvent = .breadcrumb(
            .random(),
            properties: [
                "first_key": "a_value",
                "second_key": "another_value"
            ])
        let breadcrumb = try XCTUnwrap(spanEvent as? Breadcrumb)
        XCTAssertNil(breadcrumb.attributes["first_key"])
        XCTAssertNil(breadcrumb.attributes["second_key"])
        XCTAssertNotNil(breadcrumb.attributes["message"])
        XCTAssertNotNil(breadcrumb.attributes["emb.type"])
    }

    @available(*, deprecated)
    func test_breadcrumbWithoutPropertiesAsBreadcrumbAttributesWithoutRemovingDefault() throws {
        let spanEvent: SpanEvent = .breadcrumb(.random())
        let breadcrumb = try XCTUnwrap(spanEvent as? Breadcrumb)
        XCTAssertNotNil(breadcrumb.attributes["message"])
        XCTAssertNotNil(breadcrumb.attributes["emb.type"])
    }
}
