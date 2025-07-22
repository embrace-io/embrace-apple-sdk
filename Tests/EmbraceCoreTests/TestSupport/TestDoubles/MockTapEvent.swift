//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
    import UIKit

    class MockTapEvent: UIEvent {
        private let mockedTouches: Set<UITouch>

        override var allTouches: Set<UITouch>? { mockedTouches }
        override var type: UIEvent.EventType { .touches }

        init(mockedTouches: Set<UITouch>) {
            self.mockedTouches = mockedTouches
        }
    }
#endif
