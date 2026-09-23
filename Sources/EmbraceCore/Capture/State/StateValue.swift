//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

/// A value that can be recorded as a state.
///
/// Values are compared to suppress duplicate transitions and serialized into `emb.state.*`, so a
/// conformance must keep the two in step: two values that serialize identically must compare equal,
/// or the same visible value is recorded twice.
///
/// Separate from `CustomStringConvertible` because `description` is inherited too easily to be
/// trusted as a wire format.
protocol StateValue: Equatable {
    /// Written verbatim to `emb.state.initial_value` and `emb.state.new_value`.
    var stateDescription: String { get }
}

extension String: StateValue {
    var stateDescription: String { self }
}
