//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@testable import EmbraceCore

class SpyNetworkPayloadCaptureHandler: NetworkPayloadCaptureHandler {
    private let lock = NSLock()

    private var _didCallIsEnabled: Bool = false
    var didCallIsEnabled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _didCallIsEnabled
    }

    var stubbedIsEnabled: Bool = false

    func isEnabled() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        _didCallIsEnabled = true
        return stubbedIsEnabled
    }

    private var _didCallProcess: Bool = false
    var didCallProcess: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _didCallProcess
    }

    func process(
        request: URLRequest?,
        response: URLResponse?,
        data: Data?,
        error: (any Error)?,
        startTime: Date?,
        endTime: Date?
    ) {
        lock.lock()
        defer { lock.unlock() }
        _didCallProcess = true
    }
}
