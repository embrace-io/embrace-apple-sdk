//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceOTelInternal
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
@objc(EMBCaptureService)
open class CaptureService: NSObject {

    /// Getter for the OTel handler used by the capture service.
    private(set) public weak var otel: EmbraceOpenTelemetry?

    /// `EmbraceConsoleLogger` instance used to generate internal logs.
    private(set) public weak var logger: InternalLogger?

    private(set) public weak var metadata: MetadataPropertiesHandling?

    /// Getter for the state of the capture service.
    public let state: EmbraceAtomic<CaptureServiceState> = EmbraceAtomic(.uninstalled)

    public func install(otel: EmbraceOpenTelemetry?, logger: InternalLogger? = nil) {

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
        self.metadata = metadata

        onInstall()
    }

    public func start() {

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

    public func stop() {
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
    @objc open func onInstall() {

    }

    /// This method is called by the Embrace SDK when it's been setup and started capturing data.
    /// You should override this method if your `CaptureService` needs to do something when started.
    @objc open func onStart() {

    }

    /// This method is called by the Embrace SDK when it stops capturing data.
    /// You should override this method if your `CaptureService` needs to do something when stopped.
    @objc open func onStop() {

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

extension CaptureService {

    /// Creates a `SpanBuilder` with the given parameters.
    /// Use this method to generate spans with the capture service.
    /// - Parameters:
    ///   - name: Name of the span.
    ///   - type: Type of the span.
    ///   - attributes: Attributes of the span.
    /// - Returns: The newly created `SpanBuilder` instance, or `nil` if the capture service is not active.
    public func buildSpan(name: String, type: SpanType, attributes: [String: String]) -> SpanBuilder? {
        guard isActive else {
            return nil
        }

        return otel?.buildSpan(name: name, type: type, attributes: attributes, autoTerminationCode: nil)
    }

    /// Adds the given event to the session.
    /// Use this method to generate events with the capture service.
    /// - Parameters:
    ///   - event: `RecordingSpanEvent` instance to add.
    /// - Returns: Boolean indicating if the event was successfully added. If the capture service is not active, this method always returns false.
    @discardableResult
    public func add(event: RecordingSpanEvent) -> Bool {
        guard isActive else {
            return false
        }

        otel?.add(event: event)
        return true
    }

    /// Adds the given events to the session.
    /// Use this method to generate events with the capture service.
    /// - Parameters:
    ///   - events: Array of `RecordingSpanEvents` to add.
    /// - Returns: Boolean indicating if the events were successfully added. If the capture service is not active, this method always returns false.
    @discardableResult
    public func add(events: [RecordingSpanEvent]) -> Bool {
        guard isActive else {
            return false
        }

        otel?.add(events: events)
        return true
    }
}
