//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceSemantics

class EmbraceLogAttachmentTests: XCTestCase {

    func test_init_data() throws {
        // given some attachment data
        let data = TestConstants.data

        // when creating a log attachment with it
        let attachment = EmbraceLogAttachment(data: data)

        // then the attachment is created correctly
        XCTAssertEqual(attachment.data, data)
        XCTAssertNil(attachment.url)
    }

    func test_init_url() throws {
        // given some attachment id and url
        let id = "test"
        let url = TestConstants.url

        // when creating a log attachment with them
        let attachment = EmbraceLogAttachment(id: id, url: url)

        // then the attachment is created correctly
        XCTAssertEqual(attachment.id, id)
        XCTAssertEqual(attachment.url, url)
        XCTAssertNil(attachment.data)
    }
}
