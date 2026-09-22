//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

    import Foundation
    import UIKit
    @testable import EmbraceCore
    import EmbraceSemantics

    class MockUIViewControllerHandler: UIViewControllerHandler {

        var parentSpan: EmbraceSpan?
        var parentSpanCalled = false
        override func parentSpan(for vc: UIViewController) -> EmbraceSpan? {
            parentSpanCalled = true
            return parentSpan
        }

        var onViewDidLoadStartCalled = false
        override func onViewDidLoadStart(_ vc: UIViewController, now: Date = Date()) {
            onViewDidLoadStartCalled = true
        }

        var onViewDidLoadEndCalled = false
        override func onViewDidLoadEnd(_ vc: UIViewController, now: Date = Date()) {
            onViewDidLoadEndCalled = true
        }

        var onViewWillAppearStartCalled = false
        override func onViewWillAppearStart(_ vc: UIViewController, now: Date = Date()) {
            onViewWillAppearStartCalled = true
        }

        var onViewWillAppearEndCalled = false
        override func onViewWillAppearEnd(_ vc: UIViewController, now: Date = Date()) {
            onViewWillAppearEndCalled = true
        }

        var onViewIsAppearingStartCalled = false
        override func onViewIsAppearingStart(_ vc: UIViewController, now: Date = Date()) {
            onViewIsAppearingStartCalled = true
        }

        var onViewIsAppearingEndCalled = false
        override func onViewIsAppearingEnd(_ vc: UIViewController, now: Date = Date()) {
            onViewIsAppearingEndCalled = true
        }

        var onViewDidAppearStartCalled = false
        override func onViewDidAppearStart(_ vc: UIViewController, now: Date = Date()) {
            onViewDidAppearStartCalled = true
        }

        var onViewDidAppearEndCalled = false
        override func onViewDidAppearEnd(_ vc: UIViewController, now: Date = Date()) {
            onViewDidAppearEndCalled = true
        }

        var onViewDidDisappearCalled = false
        override func onViewDidDisappear(_ vc: UIViewController) {
            onViewDidDisappearCalled = true
        }

        var onViewBecameInteractiveCalled = false
        override func onViewBecameInteractive(_ vc: UIViewController) {
            onViewBecameInteractiveCalled = true
        }
    }

#endif
