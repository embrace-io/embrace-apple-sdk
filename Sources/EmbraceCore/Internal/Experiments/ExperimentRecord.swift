//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Discriminates the two kinds of record. The raw values are the tags used in the encoded value, and
/// exist so the dashboard can present experiments and feature flags as distinct experiences.
package enum ExperimentKind: String {
    case experiment = "e"
    case featureFlag = "f"
}

/// Identity of a record.
///
/// A record is keyed by kind *and* id, so a feature flag named `dark-mode` gating a feature and an
/// experiment named `dark-mode` measuring it are two independent records, both reported.
struct ExperimentRecordKey: Hashable {
    let kind: ExperimentKind
    let id: String
}

/// A single tracked experiment or feature flag.
///
/// Both `id` and `variant` are stored already trimmed. A `variant` that was absent, empty or
/// whitespace-only is stored as `nil`, so all three inputs produce identical output.
///
/// A record carries its own encoded form, built once here and refreshed only when the record ends.
/// That is what lets `ExperimentsSerializer.serialize` join what every record already holds instead
/// of re-escaping every field of every record each time the tracked set changes.
struct ExperimentRecord {
    let kind: ExperimentKind
    let id: String
    let variant: String?
    let startedAt: Date

    /// Written at most once, either here or through ``end(at:)``. The write-once rule itself is
    /// enforced by the handler, which needs to know whether the call changed anything.
    private(set) var endedAt: Date?

    /// Encoded form of this record. `endedAt` is the only field that can change, and ``end(at:)`` is
    /// the only way to change it, so the two always move together and this can never go stale.
    private(set) var encoded: String

    init(
        kind: ExperimentKind,
        id: String,
        variant: String?,
        startedAt: Date,
        endedAt: Date? = nil
    ) {
        self.kind = kind
        self.id = id
        self.variant = variant
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.encoded = ExperimentsSerializer.encode(
            kind: kind,
            id: id,
            variant: variant,
            startedAt: startedAt,
            endedAt: endedAt
        )
    }

    var key: ExperimentRecordKey {
        ExperimentRecordKey(kind: kind, id: id)
    }

    /// Ends the record, refreshing the encoded form in the same step.
    mutating func end(at date: Date) {
        endedAt = date
        encoded = ExperimentsSerializer.encode(
            kind: kind,
            id: id,
            variant: variant,
            startedAt: startedAt,
            endedAt: date
        )
    }
}
