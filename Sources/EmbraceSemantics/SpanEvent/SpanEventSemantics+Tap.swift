//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal

public extension SpanEventType {
    static let tap = SpanEventType(ux: "tap")
}

public extension SpanEventSemantics {
    struct Tap {
        public static let name = "emb-ui-tap"
        public static let keyViewName = "view.name"
        public static let keyCoordinates = "tap.coords"
    }
}

public extension SpanType {
    @available(*, deprecated, renamed: "SpanEventType.tap", message: "Has been moved to `SpanEventType.tap`")
    static let tap = SpanType(ux: "tap")
}
