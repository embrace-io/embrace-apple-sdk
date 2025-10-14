//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import XCTest

@testable import EmbraceCore

class BreadcrumbTests: XCTestCase {
    func test_onInit_nameIsEmbBreadcrumb() {
        XCTAssertEqual(Breadcrumb(message: "").name, "emb-breadcrumb")
    }

    @available(*, deprecated)
    func test_onInitWithMessage_messageIsSavedAsAttributes() {
        let breadcrumb = Breadcrumb(message: "hello world")
        XCTAssertEqual(breadcrumb.attributes["message"], .string("hello world"))
    }

    @available(*, deprecated)
    func test_onInit_embTypeIsSysBreadcrumb() {
        let breadcrumb = Breadcrumb(message: "")
        XCTAssertEqual(breadcrumb.attributes["emb.type"], .string("sys.breadcrumb"))
    }
}
