//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

@testable import EmbraceCore

class MockUIWindowSwizzlerProvider: UIWindowSwizzlerProvider {
    let swizzler: UIWindowSendEventSwizzler

    init(swizzler: UIWindowSendEventSwizzler = MockUIWindowSendEventSwizzler()) {
        self.swizzler = swizzler
    }

    var didCallGet = false
    func get(usingHandler handler: TapCaptureServiceHandler) -> UIWindowSendEventSwizzler {
        didCallGet = true
        return swizzler
    }
}
