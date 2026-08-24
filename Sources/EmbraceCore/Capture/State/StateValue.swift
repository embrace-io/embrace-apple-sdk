//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

/// A value that can be recorded as a state.
///
/// States are compared to suppress duplicate transitions and serialized into the `emb.state.*`
/// attributes, so conformances must make both operations deliberate: two values that serialize
/// identically should compare equal, otherwise the same visible value will be recorded twice.
///
/// This is intentionally a dedicated protocol rather than a use of `CustomStringConvertible` —
/// `description` is inherited too easily and its output is not a wire contract, whereas
/// ``stateDescription`` is written verbatim into the telemetry payload.
public protocol StateValue: Equatable {
    /// Canonical serialization of this value, written to `emb.state.initial_value` and
    /// `emb.state.new_value`.
    var stateDescription: String { get }
}

extension String: StateValue {
    public var stateDescription: String { self }
}
