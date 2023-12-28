//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
    
@testable import EmbraceCore

class MockUIWindowSendEventSwizzler: UIWindowSendEventSwizzler {
    var didCallInstall = false
    var installInvokationCount = 0
    override func install() throws {
        didCallInstall = true
        installInvokationCount += 1
    }

    init() { super.init(handler: MockTapCaptureServiceHandler()) }
}
