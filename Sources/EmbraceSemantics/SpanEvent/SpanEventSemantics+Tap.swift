//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal

public extension SpanType {
    static let tap = SpanType(ux: "tap")
}

public extension SpanEventSemantics {
    struct Tap {
        public static let name = "emb-ui-tap"
        public static let keyViewName = "view.name"
        public static let keyCoordinates = "tap.coords"
    }
}
