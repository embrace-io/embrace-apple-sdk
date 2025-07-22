//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@testable import EmbraceCore

class SpyNetworkPayloadCaptureHandler: NetworkPayloadCaptureHandler {
    var didCallIsEnabled: Bool = false
    var stubbedIsEnabled: Bool = false
    func isEnabled() -> Bool {
        didCallIsEnabled = true
        return stubbedIsEnabled
    }

    var didCallProcess: Bool = false
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
