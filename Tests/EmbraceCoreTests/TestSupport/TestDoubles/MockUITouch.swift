//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
import UIKit

class MockUITouch: UITouch {
    private let overriddenPhase: Phase
    private let touchedView: UIView

    init(phase: Phase = .began, touchedView: UIView = .init()) {
        self.overriddenPhase = phase
        self.touchedView = touchedView
    }

    override var phase: UITouch.Phase { overriddenPhase }
    override var view: UIView? { touchedView }
}
#endif
