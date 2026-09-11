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
/// The modifier compiles on every platform; the type implementing this is UIKit-only. The protocol
/// is what lets the two stay apart.
protocol ManualScreenReporting: AnyObject {

    /// A declared screen became visible. `id` identifies the *view instance*, so two views showing
    /// the same name are still two screens.
    func onManualScreenAppear(
        id: ObjectIdentifier,
        name: String,
        attributes: EmbraceAttributes,
        at time: Date
    )

    func onManualScreenDisappear(id: ObjectIdentifier, name: String, at time: Date)
}

/// Where ``EmbraceScreenModifier`` finds the live reporter. A lookup because a view modifier is
/// constructed by the host app, with no route to the SDK's object graph.
///
/// Empty means no live reporter — the case whenever the gate has not passed — which is what makes
/// the modifier a silent no-op there rather than something needing a gate check of its own.
enum ManualScreenRegistry {

    /// Proof that a reporter is published, and the thing that un-publishes it.
    ///
    /// Without it the registry can be left pointing at a service that has since been replaced, and
    /// "never published" and "published then orphaned" look identical at the point of use.
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
