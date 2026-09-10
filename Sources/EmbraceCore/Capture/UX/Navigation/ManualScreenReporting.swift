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
/// A lookup rather than an injected dependency: the modifier is constructed by the host app in its
/// own view tree, and the type implementing the protocol is UIKit-only, so a modifier that compiles
/// on every platform cannot name it.
///
/// Empty means no live reporter — the case whenever the gate has not passed — which is what makes
/// the modifier a silent no-op there rather than something needing a gate check of its own.
enum ManualScreenRegistry {

    /// Proof that a reporter is published, and the thing that un-publishes it.
    ///
    /// Publishing returns one of these rather than assigning a static so that ownership decides who
    /// is published. Without it the registry can be left pointing at a service that has been
    /// replaced, and "never published" and "published then orphaned" look identical at the point of
    /// use.
    final class Registration {
        fileprivate init() {}

        deinit {
            ManualScreenRegistry.withdraw(ObjectIdentifier(self))
        }
    }

    private struct State {
        /// Weak, so this never keeps a capture service alive past its own lifetime.
        weak var reporter: ManualScreenReporting?
        /// Which registration installed the current reporter, so a stale one cannot clear a newer.
        var registration: ObjectIdentifier?
    }

    private static let state = EmbraceMutex(State())

    static var reporter: ManualScreenReporting? {
        state.withLock { $0.reporter }
    }

    /// Publishes `reporter` for as long as the returned registration is held.
    ///
    /// Deliberately **not** `@discardableResult`: dropping the registration immediately withdraws
    /// the reporter, so ignoring it is always a mistake and the compiler should say so.
    static func publish(_ reporter: ManualScreenReporting) -> Registration {
        let registration = Registration()
        state.withLock {
            $0.reporter = reporter
            $0.registration = ObjectIdentifier(registration)
        }
        return registration
    }

    /// Withdraws only if the caller is still the current publisher.
    ///
    /// The identity check is what makes replacement safe: when a second publisher takes over and the
    /// first registration is later released, its `deinit` must not clear the newer reporter.
    private static func withdraw(_ registration: ObjectIdentifier) {
        state.withLock {
            guard $0.registration == registration else { return }
            $0.reporter = nil
            $0.registration = nil
        }
    }
}
