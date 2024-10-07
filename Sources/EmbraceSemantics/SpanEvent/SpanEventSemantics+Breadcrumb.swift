//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal

public extension SpanType {
    static let breadcrumb = SpanType(system: "breadcrumb")
}

public extension SpanEventSemantics {
    @available(*, deprecated, message: "Use Breadcrumb as this struct will be removed in future versions", renamed: "Breadcrumb")
        struct Bradcrumb {
            public static let name: String = Breadcrumb.name
            public static let keyMessage: String = Breadcrumb.keyMessage
        }

        struct Breadcrumb {
            public static let name = "emb-breadcrumb"
            public static let keyMessage = "message"
        }
}
