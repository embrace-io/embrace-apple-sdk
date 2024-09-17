//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceOTelInternal
import OpenTelemetryApi

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

    /// Getter for the state of the capture service.
    @ThreadSafe
    private(set) public var state: CaptureServiceState = .uninstalled

    public func install(otel: EmbraceOpenTelemetry?, logger: InternalLogger? = nil) {
        guard state == .uninstalled else {
            return
        }

        self.otel = otel
        self.logger = logger

        onInstall()

        state = .installed
    }

    public func start() {
        guard state != .uninstalled else {
            return
        }
        state = .active

        onStart()
    }

    public func stop() {
        guard state == .active else {
            return
        }
        state = .paused

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
        guard state == .active else {
            return nil
        }

        return otel?.buildSpan(name: name, type: type, attributes: attributes)
    }

    /// Adds the given event to the session.
    /// Use this method to generate events with the capture service.
    /// - Parameters:
    ///   - event: `RecordingSpanEvent` instance to add.
    /// - Returns: Boolean indicating if the event was successfully added. If the capture service is not active, this method always returns false.
    @discardableResult
    public func add(event: RecordingSpanEvent) -> Bool {
        guard state == .active else {
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
        guard state == .active else {
            return false
        }

        otel?.add(events: events)
        return true
    }
}
