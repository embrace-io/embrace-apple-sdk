//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

import Foundation
@testable import EmbraceCore
import EmbraceCaptureService
import EmbraceOTelInternal
import TestSupport

class MockUIViewControllerHandlerDataSource: UIViewControllerHandlerDataSource {
    var state: CaptureServiceState = .active
    var otel: EmbraceOpenTelemetry? = MockEmbraceOpenTelemetry()
    var instrumentVisibility: Bool = true
    var instrumentFirstRender: Bool = true
    var blockList: ViewControllerBlockList = ViewControllerBlockList()
}

#endif
