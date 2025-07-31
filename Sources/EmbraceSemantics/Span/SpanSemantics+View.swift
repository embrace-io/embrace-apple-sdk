//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

extension SpanType {
    public static let view = SpanType(ux: "view")
    public static let viewLoad = SpanType(performance: "ui_load")
}

extension SpanSemantics {
    public struct View {
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

    public struct SwiftUIView {
        /// A span that begins the first time an instrumented body is encountered,
        /// and ends on the next tick of the run loop.
        public static let renderLoopName = "render-loop"

        /// A span that begins at the top of the `onAppear` view modifier,
        /// and ends on the next tick of the run loop.
        public static let appearName = "appear"

        /// A span that begins at the top of the `onDisappear` view modifier,
        /// and ends on the next tick of the run loop.
        public static let disappearName = "disappear"

        /// A span that begins at the top of the `body` property,
        /// and ends after the end of the `body`, using `defer{}`.
        public static let bodyName = "body"

        /// A span that begins when a `View` is first initialized, and ends
        /// when that view first appears.
        public static let timeToFirstRender = "time-to-first-render"

        /// A span that begins when a `View` is first initialized, and ends
        /// when that content is deemed complete.
        public static let timeToFirstContentComplete = "time-to-first-content-complete"

    }

    public struct SwiftUISurface {
        public static let navigatedToSurface = "surface-nav-to"
        public static let currentSurface = "surface-current"
    }
}
