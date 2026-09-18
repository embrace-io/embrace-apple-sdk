//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// The domain a state value belongs to, for values their string alone does not identify.
///
/// `"Backgrounded"` can be both the value the SDK sets while the app is backgrounded and a screen
/// someone named that; the type is what tells them apart, in memory and on the wire. Most values
/// need none.
enum StateValueType {

    /// Set by the SDK itself rather than derived from the app.
    case system

    /// What is written to `emb.state.value_type`. Not a raw value: the wire strings live in
    /// `SpanSemantics`, beside the keys they are written under.
    var wireValue: String {
        switch self {
        case .system: return SpanSemantics.State.valueTypeSystem
        }
    }
}

/// A value that can be recorded as a state.
///
/// Values are compared to suppress duplicate transitions and written into `emb.state.*`, so the two
/// must stay in step: `==` holds exactly when ``serialized`` is equal, in both directions. A
/// conformance whose `==` reads fewer fields dedupes away real transitions; one that reads more
/// ships duplicates.
///
/// Separate from `CustomStringConvertible` because `description` is inherited too easily to be
/// trusted as a wire format.
protocol StateValue: Equatable {
    /// Written verbatim to `emb.state.initial_value` and `emb.state.new_value`.
    var stateDescription: String { get }

    /// The domain this value belongs to, or `nil` when its string identifies it on its own.
    ///
    /// No default on purpose: a conformance that declared this non-optional by mistake would
    /// silently take one and ship every value untyped.
    var stateValueType: StateValueType? { get }
}

extension StateValue {

    /// The value and its type, read together.
    var serialized: SerializedStateValue {
        SerializedStateValue(stateDescription: stateDescription, type: stateValueType)
    }
}

/// A state value ready to be written: the string that goes on the wire and its type.
///
/// One read rather than two, so nothing can pair a value with a different value's type — the
/// recorder reads under its lock and writes after releasing it. ``StateValue/serialized`` is the
/// only way to make one.
struct SerializedStateValue: Equatable {

    /// Written to `emb.state.initial_value`, `emb.state.new_value`, or `emb.state.<name>` on a log.
    let stateDescription: String

    /// Written to the value-type attribute beside it, or omitted entirely when `nil`.
    let type: StateValueType?

    fileprivate init(stateDescription: String, type: StateValueType?) {
        self.stateDescription = stateDescription
        self.type = type
    }

    /// This value and its type as the attribute pair they are written as. The type is **omitted**
    /// rather than written empty: "no type" has to stay distinguishable from a type.
    ///
    /// Keys are parameters because each site stores the pair under different names — the span's
    /// `initial_value`, an event's `new_value`, a log's `emb.state.<name>`.
    func attributes(valueKey: String, typeKey: String) -> EmbraceAttributes {
        var attributes: EmbraceAttributes = [valueKey: stateDescription]
        if let type {
            attributes[typeKey] = type.wireValue
        }
        return attributes
    }
}

extension String: StateValue {
    var stateDescription: String { self }
    var stateValueType: StateValueType? { nil }
}
