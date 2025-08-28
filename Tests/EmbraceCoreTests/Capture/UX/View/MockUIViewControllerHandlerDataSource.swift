//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

    import Foundation
    import UIKit
    @testable import EmbraceCore
    import EmbraceCaptureService
    import TestSupport
    import EmbraceSemantics

    class MockUIViewControllerHandlerDataSource: UIViewControllerHandlerDataSource {
        var state: CaptureServiceState = .active
        var otel: OTelSignalsHandler? = MockOTelSignalsHandler()
        var instrumentVisibility: Bool = true
        var instrumentFirstRender: Bool = true

        var blockList: ViewControllerBlockList = ViewControllerBlockList()
        func isViewControllerBlocked(_ vc: UIViewController) -> Bool {
            return blockList.isBlocked(viewController: vc)
        }
    }

#endif
