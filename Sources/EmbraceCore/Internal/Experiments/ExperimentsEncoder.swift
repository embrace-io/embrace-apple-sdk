//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

extension EmbraceExperimentKind {
    /// The single-character tag that leads each record on the wire.
    var wireTag: String {
        self == .featureFlag ? "f" : "e"
    }
}

/// Serializes a set of experiments into the `emb.experiments` wire format:
///
///     value  = record *( ";" record )
///     record = kind ":" id ":" variant ":" start_ms [ ":" end_ms ]
///
/// `id` and `variant` are percent-escaped; timestamps are bare epoch-millisecond integers.
/// This is one-way — the handler owns the full state in memory and never decodes.
enum ExperimentsEncoder {

    static func encode(_ experiments: [Experiment]) -> String {
        experiments.map(encode).joined(separator: ";")
    }

    static func encode(_ experiment: Experiment) -> String {
        var fields = [
            experiment.kind.wireTag,
            escape(experiment.id),
            escape(experiment.variant ?? ""),
            String(milliseconds(experiment.startedAt))
        ]

        if let endedAt = experiment.endedAt {
            fields.append(String(milliseconds(endedAt)))
        }

        return fields.joined(separator: ":")
    }

    /// Percent-escapes the reserved characters. `%` is escaped first so the escape sequences
    /// introduced for `:` and `;` are not double-escaped.
    static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "%", with: "%25")
            .replacingOccurrences(of: ":", with: "%3A")
            .replacingOccurrences(of: ";", with: "%3B")
    }

    private static func milliseconds(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }
}
