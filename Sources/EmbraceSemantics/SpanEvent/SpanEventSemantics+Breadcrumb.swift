//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

extension SpanEventType {
    public static let breadcrumb = SpanEventType(system: "breadcrumb")
}

extension SpanEventSemantics {
    @available(
        *,
        deprecated,
        message: "Use Breadcrumb as this struct will be removed in future versions",
        renamed: "Breadcrumb"
    )
    public struct Bradcrumb {
        public static let name: String = Breadcrumb.name
        public static let keyMessage: String = Breadcrumb.keyMessage
    }

    public struct Breadcrumb {
        public static let name = "emb-breadcrumb"
        public static let keyMessage = "message"
    }
}

extension SpanType {
    @available(
        *,
        deprecated,
        renamed: "SpanEventType.breadcrumb",
        message: "Has been moved to `SpanEventType.breadcrumb`"
    )
    public static let breadcrumb = SpanType(system: "breadcrumb")
}
