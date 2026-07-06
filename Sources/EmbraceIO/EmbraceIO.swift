//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    @_exported import EmbraceCore
    import EmbraceCommonInternal
    import EmbraceOTelBridge
    @_exported import EmbraceSemantics
#endif

/// Main class used to interact with the Embrace SDK.
///
/// To start the SDK call `EmbraceIO.start(options:)` passing an `EmbraceIO.Options` instance.
/// The SDK is configured and started in a single step.
///
/// Example:
/// ```swift
/// import EmbraceIO
///
/// let options = EmbraceIO.Options.withAppId("appId")
/// try EmbraceIO.start(options: options)
/// ```
public class EmbraceIO {

    /// The shared `EmbraceIO` instance used to access the SDK's instance-level APIs.
    public static let shared = EmbraceIO()

    /// Returns the current state of the SDK.
    public var state: EmbraceSDKState {
        Embrace.client?.state ?? .notInitialized
    }

    /// Used to control the verbosity level of the Embrace SDK console logs.
    public var logLevel: EmbraceLogLevel = .error {
        didSet {
            Embrace.setLogLevel(logLevel)
        }
    }

    /// Returns true if the SDK is started and was not disabled through remote configurations.
    public var isSDKEnabled: Bool {
        Embrace.client?.isSDKEnabled ?? false
    }

    /// Returns the version of the Embrace SDK.
    public class var sdkVersion: String {
        return EmbraceMeta.sdkVersion
    }

    /// Returns the identifier used by Embrace for the current device, if any.
    public var deviceId: String? {
        Embrace.client?.currentDeviceId()
    }

    /// Returns the identifier for the current Embrace user session, if any.
    public var currentUserSessionId: String? {
        Embrace.client?.currentUserSessionId()
    }

    /// Method used to configure and start the Embrace SDK.
    /// - Parameter options: `EmbraceIO.Options` to be used by the SDK.
    /// - Throws: `EmbraceSetupError.invalidThread` if not called from the main thread.
    /// - Throws: `EmbraceSetupError.invalidAppId` if the provided `appId` is invalid.
    /// - Note: This method won't do anything if the Embrace SDK was already setup.
    public static func start(options: EmbraceIO.Options) throws {

        // Consturct OTel resources
        let otelResources = EmbraceDefaultResources.build(merging: options.otel?.resource)

        // Create the OTel bridge from the OTel options if provided.
        var bridge: EmbraceOTelBridge?
        if let otelOptions = options.otel {
            bridge = EmbraceOTelBridge(
                resource: otelResources,
                spanProcessors: [otelOptions.spanProcessor],
                spanExporters: [otelOptions.spanExporter],
                logProcessors: [otelOptions.logProcessor],
                logExporters: [otelOptions.logExporter]
            )
        }

        if let internalOptions = Embrace.Options.from(options: options, bridge: bridge) {
            try Embrace.setup(options: internalOptions, otelResources: otelResources.toEmbraceAttributes())
        }

        // Two-phase configuration: now that Embrace is initialized, wire the delegate, metadata
        // provider, and the captureServicesGroup that gates child span forwarding.
        if let bridge, let otel = Embrace.client?.otel {
            bridge.setup(
                delegate: otel,
                metadataProvider: otel,
                criticalResourceGroup: Embrace.client?.captureServicesGroup
            )
        }

        try EmbraceIO.shared._start()
    }

    private func _start() throws {
        try Embrace.client?.start()
    }

    /// Method used to stop the Embrace SDK from capturing and generating data.
    /// - Throws: `EmbraceSetupError.invalidThread` if not called from the main thread.
    /// - Note: This method won't do anything if the Embrace SDK was already stopped.
    /// - Note: Once stopped, The SDK can't be started again in the same process.
    public func stop() throws {
        try Embrace.client?.stop()
    }

    /// Ends the current user session immediately. The current part is closed and a new part
    /// (with the same foreground/background state) is started under a fresh user session.
    /// - Note: This call is rate-limited to once per 5 seconds. Calls within 5 seconds of the
    ///   previous one are ignored silently.
    /// - Note: This method has no effect if the SDK is stopped.
    public func endUserSession() {
        Embrace.client?.endUserSession()
    }

    /// Waits synchronously for all queued SDK work to drain.
    ///
    /// SPI for benchmarks and tests — not part of the public SDK surface.
    @_spi(Private)
    public func waitForAllWork() {
        Embrace.client?.waitForAllWork()
    }
}
