//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

/// Encodes the flat list of records carried by the `emb.experiments` attribute.
///
/// The format is a list of records joined by `;`, where each record is:
///
/// ```
/// record = kind ":" id ":" variant ":" start_ms [ ":" end_ms ]
/// kind   = "e" (experiment) | "f" (feature flag)
/// ```
///
/// Timestamps are epoch milliseconds written as bare integers. An absent variant is an empty field;
/// an absent end time is omitted entirely, so a record never ends in a blank field.
enum ExperimentsSerializer {

    static let recordSeparator = ";"
    static let fieldSeparator = ":"

    /// Joins every record into the final attribute value, or `nil` when there is nothing to report.
    ///
    /// Each record already holds its encoded form, so this only concatenates. Nothing is re-escaped,
    /// which is what keeps the cost of a change proportional to the value rather than to the work of
    /// building it from scratch.
    static func serialize(_ records: [ExperimentRecord]) -> String? {
        guard !records.isEmpty else {
            return nil
        }

        return records.map(\.encoded).joined(separator: recordSeparator)
    }

    /// Builds the encoded form of a single record.
    ///
    /// Takes the fields rather than an ``ExperimentRecord`` because a record calls this while it is
    /// still being initialized. The format lives here and nowhere else; the record only stores what
    /// this returns.
    static func encode(
        kind: ExperimentKind,
        id: String,
        variant: String?,
        startedAt: Date,
        endedAt: Date?
    ) -> String {
        var fields = [
            kind.rawValue,
            escape(id),
            escape(variant ?? ""),
            String(startedAt.millisecondsSince1970Truncated)
        ]

        if let endedAt = endedAt {
            fields.append(String(endedAt.millisecondsSince1970Truncated))
        }

        return fields.joined(separator: fieldSeparator)
    }

    /// Escapes the characters that would otherwise be read as separators.
    ///
    /// `%` must be replaced first, otherwise the `%` introduced by the later replacements would be
    /// escaped in turn and `a:b` would encode as `a%253Ab` instead of `a%3Ab`.
    static func escape(_ value: String) -> String {
        return
            value
            .replacingOccurrences(of: "%", with: "%25")
            .replacingOccurrences(of: ":", with: "%3A")
            .replacingOccurrences(of: ";", with: "%3B")
    }

}
