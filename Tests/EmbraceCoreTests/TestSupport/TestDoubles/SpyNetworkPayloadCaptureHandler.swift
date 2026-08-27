//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import TestSupport

@testable import EmbraceCore

class SpyNetworkPayloadCaptureHandler: NetworkPayloadCaptureHandler {
    @TestLocked var didCallIsEnabled: Bool = false

    var stubbedIsEnabled: Bool = false

    func isEnabled() -> Bool {
        didCallIsEnabled = true
        return stubbedIsEnabled
    }

    @TestLocked var didCallProcess: Bool = false

    func process(
        request: URLRequest?,
        response: URLResponse?,
        data: Data?,
        error: (any Error)?,
        startTime: Date?,
        endTime: Date?
    ) {
        didCallProcess = true
    }
}
