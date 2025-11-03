//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

class DictionaryEmbraceAttributesTests: XCTestCase {

    func test_setEmbraceType() {
        var attributes: EmbraceAttributes = [:]
        attributes.setEmbraceType(.performance)
        XCTAssertEqual(attributes["emb.type"] as! String, "perf")
    }

    func test_setEmbraceSessionId() {
        var attributes: EmbraceAttributes = [:]
        attributes.setEmbraceSessionId(TestConstants.sessionId)
        XCTAssertEqual(attributes["session.id"] as! String, TestConstants.sessionId.stringValue)
    }
}
