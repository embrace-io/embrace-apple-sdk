//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

class DictionaryEmbraceAttributesTests: XCTestCase {

    func test_setEmbraceType() {
        var attributes: [String: String] = [:]
        attributes.setEmbraceType(.performance)
        XCTAssertEqual(attributes["emb.type"], "perf")
    }

    func test_setEmbraceSessionId() {
        var attributes: [String: String] = [:]
        attributes.setEmbraceSessionId(TestConstants.sessionId)
        XCTAssertEqual(attributes["session.id"], TestConstants.sessionId.stringValue)
    }
}
