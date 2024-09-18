//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal

public extension SpanEventType {
    static let breadcrumb = SpanEventType(system: "breadcrumb")
}

public extension SpanEventSemantics {
    struct Bradcrumb {
        public static let name = "emb-breadcrumb"
        public static let keyMessage = "message"
    }
}
