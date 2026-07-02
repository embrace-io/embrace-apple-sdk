//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

extension EmbraceType {
    public static let breadcrumb = EmbraceType(system: "breadcrumb")
}

extension SpanEventSemantics {
    public struct Breadcrumb {
        public static let name = "emb-breadcrumb"
        public static let keyMessage = "message"
    }
}
