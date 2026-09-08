//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

/// Feeds the screens resolved by ``NavigationEventBroker`` into the generic state primitive.
///
/// Kept as its own (thin) type rather than a closure so the feature's wire parameters — the state
/// name, the default value, the per-part cap — live in one named place.
///
/// The name deliberately avoids "tracker": the view-controller observer that *produces* navigation
/// events is the other end of this same pipeline, and two similarly-named types across it would be
/// a standing source of confusion.
final class ScreenStateReporter {

    /// The `<name>` in `emb-state-<name>` and `emb.state.<name>`. Wire contract.
    static let stateName = "screen-automatic"

    /// Per-session-part ceiling on recorded transitions. Overflow is counted in
    /// `emb.state.dropped_by_instrumentation`, never recorded.
    static let maxTransitions = 1000

    /// Exposed so the capture service can register it with the ``StateCaptureCoordinator``.
    let recorder: StateRecorder<Screen>

    init(otel: EmbraceOTelSignalsHandler?) {
        recorder = StateRecorder(
            stateName: Self.stateName,
            defaultValue: .initializing,
            otel: otel,
            maxTransitions: Self.maxTransitions,
            // Eager: the screen state's span should exist for the whole part, so a session in which
            // the user never navigates still reports the screen they were on.
            capturesOnCreation: true
        )
    }

    /// Broker output sink. Signature matches ``NavigationEventBroker``'s `onScreenLoad`.
    func onScreenLoad(at time: Date, name: String) {
        recorder.onStateChange(to: Screen(name), at: time)
    }
}
