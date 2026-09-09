//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

/// What the public SwiftUI modifier needs from the navigation pipeline, and nothing else.
///
/// The modifier is compiled on every platform, while the type that implements this is UIKit-only.
/// Talking through a protocol is what lets the two stay apart: the modifier never imports UIKit,
/// never learns which capture service owns the timeline, and does not change if that ownership
/// moves — which it will, if the feature is ever extended to platforms with no view controllers.
protocol ManualScreenReporting: AnyObject {

    /// A declared screen became visible. `id` identifies the *view instance*, so two views showing
    /// the same name are still two screens.
    func onManualScreenAppear(
        id: ObjectIdentifier,
        name: String,
        attributes: EmbraceAttributes,
        at time: Date
    )

    /// A declared screen stopped being visible.
    func onManualScreenDisappear(id: ObjectIdentifier, name: String, at time: Date)
}

/// Where ``EmbraceScreenModifier`` finds the live reporter.
///
/// A lookup rather than an injected dependency because a SwiftUI view modifier has no route to the
/// SDK's object graph: it is constructed by the host app, in its own view tree, with no access to
/// whatever the SDK happens to have built.
///
/// The reference is **weak**, so this never keeps a capture service alive past its own lifetime —
/// and being empty is the normal, expected state. It stays empty whenever screen tracking is off,
/// which is exactly what makes the modifier a silent no-op in that case.
enum ManualScreenRegistry {

    private struct WeakReporter {
        weak var value: ManualScreenReporting?
    }

    private static let storage = EmbraceMutex(WeakReporter())

    static var reporter: ManualScreenReporting? {
        get { storage.withLock { $0.value } }
        set { storage.withLock { $0.value = newValue } }
    }
}
