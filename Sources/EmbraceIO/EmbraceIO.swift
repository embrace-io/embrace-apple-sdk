//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    @_exported import EmbraceCore  // so users don't have to import EmbraceIO AND EmbraceCore
    import EmbraceCommonInternal
#endif

/// Main class used to interact with the Embrace SDK.
///
/// To start the SDK you first need to configure it using an `EmbraceIO.Options` instance passed in the `setup` static method.
/// Once the SDK is setup, you can start it by calling the `EmbraceIO.shared.start()`
///
/// **Please note that even if you setup the SDK, an Embrace session will not begin until `start` is called. This means data may not be correctly attached to that session.**
///
/// Example:
/// ```swift
/// import EmbraceIO
///
/// let options = EmbraceIO.Options(appId: "appId")
/// try EmbraceIO.setup(options: options)
/// try EmbraceIO.shared.start()
/// ```
public class EmbraceIO {

    public static let shared = EmbraceIO()

    /// Returns the current state of the SDK.
    public var state: EmbraceSDKState {
        Embrace.client?.state ?? .notInitialized
    }

    /// Used to control the verbosity level of the Embrace SDK console logs.
    public var logLevel: LogLevel = .error {
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

    /// Returns the identifier for the current Embrace session, if any.
    public var currentSessionId: String? {
        Embrace.client?.currentSessionId()
    }

    /// Method used to configure the Embrace SDK.
    /// - Parameter options: `EmbraceIO.Options` to be used by the SDK.
    /// - Throws: `EmbraceSetupError.invalidThread` if not called from the main thread.
    /// - Throws: `EmbraceSetupError.invalidAppId` if the provided `appId` is invalid.
    /// - Note: This method won't do anything if the Embrace SDK was already setup.
    public static func setup(options: EmbraceIO.Options) throws {
        if let internalOptions = Embrace.Options.from(options: options) {
            try Embrace.setup(options: internalOptions)
        }
    }

    /// Method used to start the Embrace SDK.
    /// - Throws: `EmbraceSetupError.invalidThread` if not called from the main thread.
    /// - Note: This method won't do anything if the Embrace SDK was already started or if it was disabled via the remote configurations.
    public func start() throws {
        try Embrace.client?.start()
    }

    /// Method used to stop the Embrace SDK from capturing and generating data.
    /// - Throws: `EmbraceSetupError.invalidThread` if not called from the main thread.
    /// - Note: This method won't do anything if the Embrace SDK was already stopped.
    /// - Note: The SDK can't be started again once stopped.
    public func stop() throws {
        try Embrace.client?.stop()
    }

    /// Forces the Embrace SDK to start a new session.
    /// - Note: If there was a session running, it will be ended before starting a new one.
    /// - Note: This method won't do anything if the SDK is stopped.
    public func startNewSession() {
        Embrace.client?.startNewSession()
    }

    /// Forces the Embrace SDK to stop the current session, if any.
    /// - Note: This method won't do anything if the SDK is stopped.
    public func endCurrentSession() {
        Embrace.client?.endCurrentSession()
    }

    /// Call this if you want the Embrace SDK to clear the upload cache data on the next launch.
    public func resetUploadCache() {
        Embrace.client?.resetUploadCache()
    }
}
