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
    import EmbraceCommonInternal

    class MockUIViewControllerHandlerDataSource: UIViewControllerHandlerDataSource {
        var serviceState: CaptureServiceState = .active
        var otel: EmbraceOTelSignalsHandler? = MockOTelSignalsHandler()
        var instrumentVisibility: Bool = true
        var instrumentFirstRender: Bool = true

        var blockList: ViewControllerBlockList = ViewControllerBlockList()
        func isViewControllerBlocked(_ vc: UIViewController) -> Bool {
            return blockList.isBlocked(viewController: vc)
        }

        /// Recorded so tests can assert the handler taps the navigation seam at the right moments,
        /// on the calling thread, with the callback's own timestamp.
        private(set) var appearanceCalls: [(vc: UIViewController, phase: ScreenAppearancePhase, time: Date)] = []

        func onViewControllerAppearance(_ vc: UIViewController, phase: ScreenAppearancePhase, at time: Date) {
            appearanceCalls.append((vc, phase, time))
        }
    }

#endif
