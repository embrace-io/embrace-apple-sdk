//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

extension EmbraceType {
    public static let tap = EmbraceType(ux: "tap")
}

extension SpanEventSemantics {
    public struct Tap {
        public static let name = "emb-ui-tap"
        public static let keyViewName = "view.name"
        public static let keyCoordinates = "tap.coords"
    }
}
