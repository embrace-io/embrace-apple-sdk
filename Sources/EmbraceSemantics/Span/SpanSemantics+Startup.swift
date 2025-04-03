//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal

public extension SpanType {
    static let startup = SpanType(system: "startup")
}

public extension SpanSemantics {
    struct Startup {
        public static let parentName = "emb-app-startup"

        public static let preMainInitName = "emb-app-pre-main-init"
        public static let appInitName = "emb-app-startup-app-init"
        public static let firstFrameRenderedName = "emb-app-first-frame-rendered"

        public static let sdkSetup = "emb-sdk-setup"
        public static let sdkStart = "emb-sdk-start"

        public static let keyPrewarmed = "isPrewarmed"
    }
}
