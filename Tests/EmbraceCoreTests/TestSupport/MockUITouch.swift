//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
    

import UIKit

class MockUITouch: UITouch {
    private let overridenPhase: Phase
    private let touchedView: UIView

    init(phase: Phase = .began, touchedView: UIView = .init()) {
        self.overridenPhase = phase
        self.touchedView = touchedView
    }

    override var phase: UITouch.Phase { overridenPhase }
    override var view: UIView? { touchedView }
}
