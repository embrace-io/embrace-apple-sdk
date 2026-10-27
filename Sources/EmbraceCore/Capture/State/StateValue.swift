//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// A value that can be recorded as a state.
///
/// Values are compared to suppress duplicate transitions and written into `emb.state.*`, so the two
/// must stay in step: `==` holds exactly when ``stateDescription`` and ``isSystemValue`` are both
/// equal. A conformance whose `==` reads fewer fields dedupes away real transitions; one that reads
/// more ships duplicates.
///
/// Separate from `CustomStringConvertible` because `description` is inherited too easily to be
/// trusted as a wire format.
protocol StateValue: Equatable {
    /// Written verbatim to `emb.state.initial_value` and `emb.state.new_value`.
    var stateDescription: String { get }

    /// Whether the SDK set this value itself rather than deriving it from the app.
    ///
    /// `"Backgrounded"` can be both the value the SDK sets while the app is backgrounded and a screen
    /// someone named that; this is what tells them apart, in memory and on the wire.
    ///
    /// No default on purpose: every conformance has to answer it.
    var isSystemValue: Bool { get }
}

extension StateValue {

    /// This value as the attribute pair it is written as. The type is **omitted** for app values
    /// rather than written empty: "no type" has to stay distinguishable from a type.
    ///
    /// Keys are parameters because each site stores the pair under different names — the span's
    /// `initial_value`, an event's `new_value`, a log's `emb.state.<name>`.
    func attributes(valueKey: String, typeKey: String) -> EmbraceAttributes {
        var attributes: EmbraceAttributes = [valueKey: stateDescription]
        if isSystemValue {
            attributes[typeKey] = SpanSemantics.State.valueTypeSystem
        }
        return attributes
    }
}

extension String: StateValue {
    var stateDescription: String { self }
    var isSystemValue: Bool { false }
}
