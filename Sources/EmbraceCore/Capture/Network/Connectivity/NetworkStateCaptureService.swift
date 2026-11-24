//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCaptureService
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

/// Records the device's connectivity as the `network` state: one `emb-state-network` span per
/// session part, with a `transition` event per connectivity change.
///
/// There is deliberately no remote-config gate — presence in the capture options is the only
/// switch. The state starts with no value: the first path observed becomes the span's
/// `initial_value` rather than a transition, so a launch never fabricates an `unknown` →
/// real-value change.
public final class NetworkStateCaptureService: CaptureService {

    static let stateName = "network"
    static let maxTransitions = 100

    private struct MutableState {
        var recorder: StateRecorder<NetworkConnectivity>?
        var monitor: NetworkPathMonitoring?
    }

    private let mutableState = EmbraceMutex(MutableState())
    private let createMonitor: () -> NetworkPathMonitoring

    /// The recorder, once the first start has built it.
    var recorder: StateRecorder<NetworkConnectivity>? {
        mutableState.withLock { $0.recorder }
    }

    override public convenience init() {
        self.init(createMonitor: { NetworkPathMonitor() })
    }

    init(createMonitor: @escaping () -> NetworkPathMonitoring) {
        self.createMonitor = createMonitor
        super.init()
    }

    deinit {
        mutableState.withLock { $0.monitor }?.cancel()
    }

    override public func onStart() {
        // Built and registered at most once. `StateController` has no `unregister`, so a second
        // recorder would mean two `emb-state-network` spans in every later part. Keeping the one
        // recorder registered across a stop is also what gives later parts a span carrying the
        // last known value after the SDK stops observing.
        let recorder: StateRecorder<NetworkConnectivity>
        let existing = mutableState.withLock { $0.recorder }
        if let existing {
            recorder = existing
        } else {
            recorder = StateRecorder(
                stateName: Self.stateName,
                initialValue: nil,
                otel: otel,
                maxTransitions: Self.maxTransitions
            )
            mutableState.withLock { $0.recorder = recorder }
            Embrace.client?.stateController.register(recorder)
        }

        // A fresh monitor on every start: `NWPathMonitor` cannot be restarted once cancelled.
        let monitor = createMonitor()
        monitor.onPathUpdate = { [weak self] snapshot, time in
            // The active check is what stops a cancelled monitor's late deliveries from being
            // recorded after the SDK stops.
            guard let self, self.isActive else {
                return
            }
            recorder.onStateChange(to: NetworkConnectivity(snapshot), at: time)
        }

        let previous = mutableState.withLock { state -> NetworkPathMonitoring? in
            let previous = state.monitor
            state.monitor = monitor
            return previous
        }
        previous?.cancel()

        monitor.start()
    }

    override public func onStop() {
        let monitor = mutableState.withLock { state -> NetworkPathMonitoring? in
            let monitor = state.monitor
            state.monitor = nil
            return monitor
        }
        monitor?.cancel()
    }
}
