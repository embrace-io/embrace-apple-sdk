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

    func test_setSessionIdentity_stampsThreeKeys() {
        var attributes: EmbraceAttributes = [:]
        attributes.setSessionIdentity(userSessionId: "U1", partId: "P1")
        XCTAssertEqual(attributes["session.id"] as! String, "U1")
        XCTAssertEqual(attributes["emb.user_session_id"] as! String, "U1")
        XCTAssertEqual(attributes["emb.session_part_id"] as! String, "P1")
    }

    func test_setSessionIdentity_emptyStringsWhenUnknown() {
        var attributes: EmbraceAttributes = [:]
        attributes.setSessionIdentity(userSessionId: "", partId: "")
        XCTAssertEqual(attributes["session.id"] as! String, "")
        XCTAssertEqual(attributes["emb.user_session_id"] as! String, "")
        XCTAssertEqual(attributes["emb.session_part_id"] as! String, "")
    }
}
