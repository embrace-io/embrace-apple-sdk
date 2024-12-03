//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

import Foundation
import UIKit
@testable import EmbraceCore
import OpenTelemetryApi

class MockUIViewControllerHandler: UIViewControllerHandler {

    var parentSpan: Span?
    var parentSpanCalled = false
    override func parentSpan(for vc: UIViewController) -> Span? {
        parentSpanCalled = true
        return parentSpan
    }

    var onViewDidLoadStartCalled = false
    override func onViewDidLoadStart(_ vc: UIViewController) {
        onViewDidLoadStartCalled = true
    }

    var onViewDidLoadEndCalled = false
    override func onViewDidLoadEnd(_ vc: UIViewController) {
        onViewDidLoadEndCalled = true
    }

    var onViewWillAppearStartCalled = false
    override func onViewWillAppearStart(_ vc: UIViewController) {
        onViewWillAppearStartCalled = true
    }

    var onViewWillAppearEndCalled = false
    override func onViewWillAppearEnd(_ vc: UIViewController) {
        onViewWillAppearEndCalled = true
    }

    var onViewDidAppearStartCalled = false
    override func onViewDidAppearStart(_ vc: UIViewController) {
        onViewDidAppearStartCalled = true
    }

    var onViewDidAppearEndCalled = false
    override func onViewDidAppearEnd(_ vc: UIViewController) {
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
