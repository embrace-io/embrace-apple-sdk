//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
#endif

public extension SpanType {
    static let view = SpanType(ux: "view")
    static let viewLoad = SpanType(performance: "ui_load")
}

public extension SpanSemantics {
    struct View {
        public static let screenName = "emb-screen-view"
        public static let timeToFirstRenderName = "emb-NAME-time-to-first-render"
        public static let timeToInteractiveName = "emb-NAME-time-to-interactive"
        public static let viewDidLoadName = "emb-view-did-load"
        public static let viewWillAppearName = "emb-view-will-appear"
        public static let viewIsAppearingName = "emb-view-is-appearing"
        public static let viewDidAppearName = "emb-view-did-appear"
        public static let uiReadyName = "ui-ready"
        public static let keyViewTitle = "view.title"
        public static let keyViewName = "view.name"
    }
    
    struct SwiftUIView {
        public static let viewLoadName = "swiftui-view-ui-load"
        public static let initToOnAppearName = "init-to-appear"
        public static let firstRenderCycleName = "first-render-cycle"
        public static let bodyExecutionName = "body-execution"
    }
}
