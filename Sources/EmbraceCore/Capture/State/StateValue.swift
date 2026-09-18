//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// The domain a state value belongs to, for values their string alone does not identify.
///
/// The SDK's own values share a namespace with the app's, and the app's are arbitrary strings, so
/// `"Backgrounded"` can be both the value set while the app is backgrounded and a screen someone
/// named that. The type travels with the value in memory and is written beside it on the wire, so
/// neither equality nor a consumer has to guess which is which. Most values need none.
enum StateValueType {

    /// Set by the SDK itself rather than derived from the app.
    case system

    /// What is written to `emb.state.value_type`. Deliberately not a raw value: the strings are a
    /// wire contract and live in `SpanSemantics` with the keys they are written under.
    var wireValue: String {
        switch self {
        case .system: return SpanSemantics.State.valueTypeSystem
        }
    }
}

/// A value that can be recorded as a state.
///
/// Values are compared to suppress duplicate transitions and serialized into `emb.state.*`, so a
/// conformance must keep the two in step: two values that serialize identically must compare equal,
/// or the same visible value is recorded twice. A conformance with a ``stateValueType`` must
/// include it in its `==` — differently-typed values are different values.
///
/// Separate from `CustomStringConvertible` because `description` is inherited too easily to be
/// trusted as a wire format.
protocol StateValue: Equatable {
    /// Written verbatim to `emb.state.initial_value` and `emb.state.new_value`.
    var stateDescription: String { get }

    /// The domain this value belongs to, or `nil` when its string identifies it on its own.
    var stateValueType: StateValueType? { get }
}

extension StateValue {

    var stateValueType: StateValueType? { nil }

    /// The value as it is written, with its type, in one read.
    var serialized: SerializedStateValue {
        SerializedStateValue(description: stateDescription, type: stateValueType)
    }
}

/// A state value ready to be written: the string that goes on the wire and its type.
///
/// One read rather than two, so nothing can pair a value with a different value's type — the
/// recorder reads under its lock and writes after releasing it, and a log stamps each state in turn.
struct SerializedStateValue: Equatable {

    /// Written to `emb.state.initial_value`, `emb.state.new_value`, or `emb.state.<name>` on a log.
    let description: String

    /// Written to the value-type attribute beside it, or omitted entirely when `nil`.
    let type: StateValueType?
}

extension String: StateValue {
    var stateDescription: String { self }
}
