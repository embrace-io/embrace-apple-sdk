//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

extension SpanEventSemantics {
    /// Attribute keys and values for the span event recorded on a network span parent that was
    /// replaced by another one while it was still active.
    public struct NetworkSpanParent {
        public static let nameReplaced = "emb-network-span-parent-replaced"
        public static let keyReplacedBySpanId = "emb.replaced_by.span_id"
        public static let keyReplacedByName = "emb.replaced_by.name"
    }
}
