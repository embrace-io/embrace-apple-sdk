//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// A single normalized navigation input, ready for ``NavigationEventBroker``.
///
/// Not `Equatable`: attribute values are an open protocol with no equality, and an `==` that
/// skipped them would silently pass for two events differing only in the field a test compared.
struct NavigationEvent {

    enum Kind: Equatable {
        /// The container began appearing (`viewWillAppear`). Records a start time; emits nothing.
        case started
        /// The container finished appearing (`viewDidAppear`). This is what drives a transition.
        case resumed
        /// The container finished disappearing (`viewDidDisappear`).
        case paused
        /// The app backgrounded, from the SDK's app-state signal — so navigation and session
        /// backgrounding share one timestamp.
        case backgrounded
        /// The app returned to the foreground, from that same app-state signal.
        case foregrounded
    }

    let kind: Kind

    /// Screen name. Empty for app-scoped events, whose name is supplied by the broker.
    let name: String

    /// Identity of the emitting container, or `nil` for app-scoped events. **Instance** identity,
    /// not class — two instances of the same controller class must not collapse into one.
    let componentId: ObjectIdentifier?

    /// When the originating OS callback fired — never "now". All downstream processing uses this.
    let timestamp: Date

    /// Caller-supplied metadata for the transition this event produces, if any.
    ///
    /// Only ever non-empty for screens declared through the public SwiftUI modifier, which is the
    /// one producer that lets a developer attach their own data. Automatic view-controller events
    /// leave it empty, so nothing on that path changes.
    let attributes: EmbraceAttributes

    // MARK: - Factories

    static func started(_ componentId: ObjectIdentifier, name: String, at timestamp: Date) -> NavigationEvent {
        NavigationEvent(
            kind: .started, name: name, componentId: componentId, timestamp: timestamp, attributes: [:])
    }

    static func resumed(
        _ componentId: ObjectIdentifier,
        name: String,
        at timestamp: Date,
        attributes: EmbraceAttributes = [:]
    ) -> NavigationEvent {
        NavigationEvent(
            kind: .resumed, name: name, componentId: componentId, timestamp: timestamp, attributes: attributes)
    }

    static func paused(_ componentId: ObjectIdentifier, name: String, at timestamp: Date) -> NavigationEvent {
        NavigationEvent(
            kind: .paused, name: name, componentId: componentId, timestamp: timestamp, attributes: [:])
    }

    static func backgrounded(at timestamp: Date) -> NavigationEvent {
        NavigationEvent(kind: .backgrounded, name: "", componentId: nil, timestamp: timestamp, attributes: [:])
    }

    static func foregrounded(at timestamp: Date) -> NavigationEvent {
        NavigationEvent(kind: .foregrounded, name: "", componentId: nil, timestamp: timestamp, attributes: [:])
    }
}
