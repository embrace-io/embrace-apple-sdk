//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import Foundation

@testable import EmbraceCore
import EmbraceCommon

class EmbraceMetaUserAgentTests: XCTestCase {

    func test_userAgent_matchesFormat() {
        XCTAssertEqual(EmbraceMeta.userAgent, "Embrace/i/\(EmbraceMeta.sdkVersion)")
    }

}
