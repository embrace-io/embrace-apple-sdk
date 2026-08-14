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
struct ExperimentRecord {
    let kind: ExperimentKind
    let id: String
    let variant: String?
    let startedAt: Date
    var endedAt: Date?

    var key: ExperimentRecordKey {
        ExperimentRecordKey(kind: kind, id: id)
    }
}
