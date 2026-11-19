//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

/// The device's connectivity, as recorded by the `network` state.
///
/// The raw values are the wire contract, shared with Android so one backend query serves both
/// platforms. `mixed` is derived by the backend when a session's values differ, so it is never
/// emitted. Android's `unverified` and `*_connecting` values come from its two-phase validation
/// model; a satisfied path here is already validated, so they have no equivalent.
enum NetworkConnectivity: String, StateValue {

    /// Connected over WiFi. Takes precedence: a path that is both WiFi and cellular is WiFi.
    case wifi

    /// Connected over cellular, with no generation (2G–5G) granularity.
    case wan

    /// Connected, but over an interface that is neither WiFi nor cellular (wired or
    /// unclassified).
    case unknown

    /// No connectivity.
    case none

    var stateDescription: String { rawValue }

    /// Never a system value: `value_type` exists to keep an SDK-set value apart from an
    /// app-supplied one of the same name, and no network value can come from the app.
    var isSystemValue: Bool { false }

    init(_ path: NetworkPathSnapshot) {
        if !path.isSatisfied {
            self = .none
        } else if path.usesWiFi {
            self = .wifi
        } else if path.usesCellular {
            self = .wan
        } else {
            self = .unknown
        }
    }
}
