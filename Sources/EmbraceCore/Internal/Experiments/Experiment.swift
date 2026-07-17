//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// A single experiment or feature flag the user is enrolled in.
/// Immutable once created except for `endedAt`, which can be set exactly once.
struct Experiment {
    let id: String
    let kind: EmbraceExperimentKind
    let variant: String?
    let startedAt: Date
    var endedAt: Date?
}
