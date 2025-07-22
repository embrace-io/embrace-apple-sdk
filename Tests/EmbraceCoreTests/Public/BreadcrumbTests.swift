//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import XCTest

@testable import EmbraceCore

class BreadcrumbTests: XCTestCase {
    func test_onInit_nameIsEmbBreadcrumb() {
        XCTAssertEqual(Breadcrumb(message: "", attributes: .empty()).name, "emb-breadcrumb")
    }

    func test_onInitWithMessage_messageIsSavedAsAttributes() {
        let breadcrumb = Breadcrumb(message: "hello world", attributes: .empty())
        XCTAssertEqual(breadcrumb.attributes["message"], .string("hello world"))
    }

    func test_onInit_embTypeIsSysBreadcrumb() {
        let breadcrumb = Breadcrumb(message: "", attributes: .empty())
        XCTAssertEqual(breadcrumb.attributes["emb.type"], .string("sys.breadcrumb"))
    }
}
