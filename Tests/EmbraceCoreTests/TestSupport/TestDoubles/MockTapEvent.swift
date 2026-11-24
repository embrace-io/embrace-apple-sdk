//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
    import UIKit

    class MockTapEvent: UIEvent {
        private let mockedTouches: Set<UITouch>
        private let mockedType: UIEvent.EventType
        private let mockedTimestamp: TimeInterval

        override var allTouches: Set<UITouch>? { mockedTouches }
        override var type: UIEvent.EventType { mockedType }
        override var timestamp: TimeInterval { mockedTimestamp }

        init(mockedTouches: Set<UITouch>, type: UIEvent.EventType = .touches, timestamp: TimeInterval = 0) {
            self.mockedTouches = mockedTouches
            self.mockedType = type
            self.mockedTimestamp = timestamp
        }
    }
#endif
