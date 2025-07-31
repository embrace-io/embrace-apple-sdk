//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import Foundation
import XCTest

@testable import EmbraceCore

class EmbraceMetaUserAgentTests: XCTestCase {

    func test_userAgent_matchesFormat() {
        XCTAssertEqual(EmbraceMeta.userAgent, "Embrace/i/\(EmbraceMeta.sdkVersion)")
    }

}
