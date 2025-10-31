//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
    import EmbraceConfiguration
#endif

/// Base class for all capture services (this class should never be used directly)
/// In order to make your own `CaptureService` you should create a subclass and override
/// the necessary methods.
///
/// A `CaptureService` is an object that can be passed to the Embrace during setup
/// and that will capture and generate data in Open Telemetry format.
/// Multiple `CaptureServices` can run at the same time and be in charge of handling
/// different types of data.
///
/// This base class provides the necessary functionality and structure that should be used
/// by all capture services.
open class CaptureService {

    /// Getter for the OTel signals handler used by the capture service.
    private(set) package weak var otel: EmbraceOTelSignalsHandler?

    /// `EmbraceConsoleLogger` instance used to generate internal logs.
    private(set) public weak var logger: InternalLogger?

    /// Getter for the state of the capture service.
    public let state: EmbraceAtomic<CaptureServiceState> = EmbraceAtomic(.uninstalled)

    public init() {}

    package func install(otel: EmbraceOTelSignalsHandler?, logger: InternalLogger? = nil) {

        guard
            state.compareExchange(
                expected: .uninstalled,
                desired: .installed
            )
        else {
            return
        }

        self.otel = otel
        self.logger = logger

        onInstall()
    }

    package func start() {

        // Allow to go from installed -> active
        if state.compareExchange(expected: .installed, desired: .active) {
            onStart()
            return
        }

        // Or allow to go from paused -> active
        if state.compareExchange(expected: .paused, desired: .active) {
            onStart()
            return
        }
    }

    package func stop() {
        guard
            state.compareExchange(
                expected: .active,
                desired: .paused
            )
        else {
            return
        }

        onStop()
    }

    /// This method will be called once when the Embrace SDK starts.
    /// You should override this method if your `CaptureService` needs some sort of
    /// setup process before it can start generating data.
    open func onInstall() {

    }

    /// This method is called by the Embrace SDK when it's been setup and started capturing data.
    /// You should override this method if your `CaptureService` needs to do something when started.
    open func onStart() {

    }

    /// This method is called by the Embrace SDK when it stops capturing data.
    /// You should override this method if your `CaptureService` needs to do something when stopped.
    open func onStop() {

    }

    /// This method is called by the Embrace SDK when a new session starts.
    /// You should override this method if your `CaptureService` needs to do something on a new session.
    open func onSessionStart(_ session: EmbraceSession) {

    }

    /// This method is called by the Embrace SDK when a session will end.
    /// You should override this method if your `CaptureService` needs to do something before a session ends.
    open func onSessionWillEnd(_ session: EmbraceSession) {

    }

    /// This method is called by the Embrace SDK when the configuration is updated.
    /// You should override this method if your `CaptureService` needs to do something.
    open func onConfigUpdated(_ config: EmbraceConfigurable) {

    }
}

extension CaptureService {

    public var isInstalled: Bool {
        state.load() == .installed
    }

    public var isUninstalled: Bool {
        state.load() == .uninstalled
    }

    public var isActive: Bool {
        state.load() == .active
    }

    public var isPaused: Bool {
        state.load() == .paused
    }
}
