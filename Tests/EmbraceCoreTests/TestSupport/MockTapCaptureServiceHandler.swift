//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit)
import UIKit

import EmbraceCommon
@testable import EmbraceCore

class MockTapCaptureServiceHandler: TapCaptureServiceHandler {
    var didCallHandlerCapturedEvent = false
    var handleCapturedEventParameter: UIEvent?
    func handleCapturedEvent(_ event: UIEvent) {
        didCallHandlerCapturedEvent = true
        handleCapturedEventParameter = event
    }

    var didCallChangedState = false
    var changedStateReceivedParameter: CaptureServiceState?
    func changedState(to captureServiceState: CaptureServiceState) {
        didCallChangedState = true
        changedStateReceivedParameter = captureServiceState
    }
}
#endif
