//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// A single normalized navigation input, ready for ``NavigationEventBroker``.
struct NavigationEvent: Equatable {

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

    // MARK: - Factories

    static func started(_ componentId: ObjectIdentifier, name: String, at timestamp: Date) -> NavigationEvent {
        NavigationEvent(kind: .started, name: name, componentId: componentId, timestamp: timestamp)
    }

    static func resumed(_ componentId: ObjectIdentifier, name: String, at timestamp: Date) -> NavigationEvent {
        NavigationEvent(kind: .resumed, name: name, componentId: componentId, timestamp: timestamp)
    }

    static func paused(_ componentId: ObjectIdentifier, name: String, at timestamp: Date) -> NavigationEvent {
        NavigationEvent(kind: .paused, name: name, componentId: componentId, timestamp: timestamp)
    }

    static func backgrounded(at timestamp: Date) -> NavigationEvent {
        NavigationEvent(kind: .backgrounded, name: "", componentId: nil, timestamp: timestamp)
    }

    static func foregrounded(at timestamp: Date) -> NavigationEvent {
        NavigationEvent(kind: .foregrounded, name: "", componentId: nil, timestamp: timestamp)
    }
}
