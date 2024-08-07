//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal

public extension SpanType {
    static let view = SpanType(ux: "view")
}

public extension SpanSemantics {
    struct View {
        public static let name = "emb-screen-view"
        public static let keyViewTitle = "view.title"
        public static let keyViewName = "view.name"
    }
}
