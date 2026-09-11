//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

/// Feeds the screens resolved by ``NavigationEventBroker`` into the generic state primitive.
final class ScreenStateReporter {

    /// The `<name>` in `emb-state-<name>` and `emb.state.<name>`. Wire contract.
    static let stateName = "screen-automatic"

    /// Per-session-part ceiling on recorded transitions. Overflow is counted in
    /// `emb.state.dropped_by_instrumentation`, never recorded.
    static let maxTransitions = 1000

    let recorder: StateRecorder<Screen>

    init(otel: EmbraceOTelSignalsHandler?) {
        recorder = StateRecorder(
            stateName: Self.stateName,
            defaultValue: .initializing,
            otel: otel,
            maxTransitions: Self.maxTransitions,
            // Eager, so a session in which the user never navigates still reports their screen.
            capturesOnCreation: true
        )
    }

    func onScreenLoad(at time: Date, name: String) {
        recorder.onStateChange(to: Screen(name), at: time)
    }
}
