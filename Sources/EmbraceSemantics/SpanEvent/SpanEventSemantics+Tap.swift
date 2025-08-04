//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

extension SpanEventType {
    public static let tap = SpanEventType(ux: "tap")
}

extension SpanEventSemantics {
    public struct Tap {
        public static let name = "emb-ui-tap"
        public static let keyViewName = "view.name"
        public static let keyCoordinates = "tap.coords"
    }
}

extension SpanType {
    @available(*, deprecated, renamed: "SpanEventType.tap", message: "Has been moved to `SpanEventType.tap`")
    public static let tap = SpanType(ux: "tap")
}
