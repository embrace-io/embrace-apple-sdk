//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceConfigInternal
import EmbraceOTelInternal
import EmbraceStorageInternal
import EmbraceUploadInternal
import EmbraceObjCUtilsInternal

/**
 Main class used to interact with the Embrace SDK.

To start the SDK you first need to configure it using an `Embrace.Options` instance passed in the `setup` static method.
 Once the SDK is setup, you can start it by calling the `start` instance method.

 **Please note that even if you setup the SDK, an Embrace session will not begin until `start` is called. This means data may not be correctly attached to that session.**

 Example:
 ```swift
 import EmbraceIO
 
 let options = Embrace.Options(appId: "appId", platform: .iOS)
 try Embrace.setup(options: options)
 try Embrace.client?.start()
 ```
*/
@objc public class Embrace: NSObject {

    /**
     Returns the current `Embrace` client.

     This will be `nil` until the `setup` method is called, or if the setup process fails.
     */
    @objc public internal(set) static var client: Embrace?

    /// The `Embrace.Options` that were used to configure the SDK.
    @objc public private(set) var options: Embrace.Options

    /// Returns whether the SDK was started.
    @objc public private(set) var started: Bool

    /// Returns the `DeviceIdentifier` used by Embrace for the current device.
    public private(set) var deviceId: DeviceIdentifier

    /// Used to control the verbosity level of the Embrace SDK console logs.
    @objc public var logLevel: LogLevel = .error {
        didSet {
            Embrace.logger.level = logLevel
        }
    }

    /// Returns the version of the Embrace SDK.
    @objc public class var sdkVersion: String {
        return EmbraceMeta.sdkVersion
    }

    /// Returns the current `MetadataHandler` used to store resources and session properties.
    public let metadata: MetadataHandler

    let config: EmbraceConfig?
    let storage: EmbraceStorage
    let upload: EmbraceUpload?
    let captureServices: CaptureServices

    let logController: LogControllable

    let sessionController: SessionController
    let sessionLifecycle: SessionLifecycle

    private let processingQueue = DispatchQueue(
        label: "com.embrace.processing",
        qos: .background,
        attributes: .concurrent
    )
    private static let synchronizationQueue = DispatchQueue(
        label: "com.embrace.synchronization",
        qos: .utility
    )

    static let notificationCenter: NotificationCenter = NotificationCenter()

    static let logger: DefaultInternalLogger = DefaultInternalLogger()

    /// Method used to configure the Embrace SDK.
    /// - Parameter options: `Embrace.Options` to be used by the SDK.
    /// - Throws: `EmbraceSetupError.invalidThread` if not called from the main thread.
    /// - Throws: `EmbraceSetupError.invalidAppId` if the provided `appId` is invalid.
    /// - Throws: `EmbraceSetupError.invalidAppGroupId` if the provided `appGroupId` is invalid.
    /// - Throws: `EmbraceSetupError.invalidOptions` when providing more than one `CrashReporter`.
    /// - Note: This method won't do anything if the Embrace SDK was already setup.
    /// - Returns: The `Embrace` client instance.
    @discardableResult
    @objc public static func setup(options: Embrace.Options) throws -> Embrace {
        if !Thread.isMainThread {
            throw EmbraceSetupError.invalidThread("Embrace must be setup on the main thread")
        }

        if ProcessInfo.processInfo.isSwiftUIPreview {
            throw EmbraceSetupError.initializationNotAllowed("Embrace cannot be initialized on SwiftUI Previews")
        }

        let startTime = Date()

        return try Embrace.synchronizationQueue.sync {
            if let client = client {
                Embrace.logger.warning("Embrace was already initialized!")
                return client
            }

            try options.validate()

            client = try Embrace(options: options)
            if let client = client {
                client.recordSetupSpan(startTime: startTime)
                return client
            } else {
                throw EmbraceSetupError.unableToInitialize("Unable to initialize Embrace.client")
            }
        }
    }

    private override init() {
        fatalError("Use init(options:) instead")
    }

    deinit {
        Embrace.notificationCenter.removeObserver(self)
    }

    init(options: Embrace.Options,
         logControllable: LogControllable? = nil,
         embraceStorage: EmbraceStorage? = nil) throws {
        self.started = false
        self.options = options

        self.logLevel = options.logLevel

        self.storage = try embraceStorage ?? Embrace.createStorage(options: options)
        self.deviceId = DeviceIdentifier.retrieve(from: storage)
        self.upload = Embrace.createUpload(options: options, deviceId: deviceId.hex)
        self.captureServices = try CaptureServices(options: options, storage: storage, upload: upload)
        self.config = Embrace.createConfig(options: options, deviceId: deviceId.hex)
        self.sessionController = SessionController(storage: storage, upload: upload)
        self.sessionLifecycle = Embrace.createSessionLifecycle(controller: sessionController)
        self.metadata = MetadataHandler(storage: storage, sessionController: sessionController)
        self.logController = logControllable ?? LogController(
            storage: storage,
            upload: upload,
            controller: sessionController
        )
        super.init()

        // setup otel
        EmbraceOTel.setup(spanProcessors: .processors(for: storage, export: options.export))
        let logSharedState = DefaultEmbraceLogSharedState.create(
            storage: self.storage,
            controller: logController,
            exporter: options.export?.logExporter
        )
        EmbraceOTel.setup(logSharedState: logSharedState)
        sessionLifecycle.setup()
        Embrace.logger.otel = self

        // config update event
        Embrace.notificationCenter.addObserver(
            self,
            selector: #selector(onConfigUpdated),
            name: .embraceConfigUpdated, object: nil
        )
    }

    /// Method used to start the Embrace SDK.
    /// - Throws: `EmbraceSetupError.invalidThread` if not called from the main thread.
    /// - Note: This method won't do anything if the Embrace SDK was already started or if it was disabled via the remote configurations.
    /// - Returns: The `Embrace` client instance.
    @discardableResult
    @objc public func start() throws -> Embrace {
        guard Thread.isMainThread else {
            throw EmbraceSetupError.invalidThread("Embrace must be started on the main thread")
        }

        Embrace.synchronizationQueue.sync {
            guard started == false else {
                Embrace.logger.warning("Embrace was already started!")
                return
            }

            guard config == nil || config?.isSDKEnabled == true else {
                Embrace.logger.warning("Embrace can't start when disabled!")
                return
            }

            let processStartSpan = createProcessStartSpan()
            defer { processStartSpan.end() }

            recordSpan(name: "emb-sdk-start", parent: processStartSpan, type: .performance) { _ in
                started = true

                sessionLifecycle.start()
                captureServices.start()

                processingQueue.async { [weak self] in
                    // fetch crash reports and link them to sessions
                    // then upload them
                    UnsentDataHandler.sendUnsentData(
                        storage: self?.storage,
                        upload: self?.upload,
                        otel: self,
                        logController: self?.logController,
                        currentSessionId: self?.sessionController.currentSession?.id,
                        crashReporter: self?.captureServices.crashReporter
                    )

                    // retry any remaining cached upload data
                    self?.upload?.retryCachedData()
                }
            }
        }

        return self
    }

    /// Returns the current session identifier, if any.
    @objc public func currentSessionId() -> String? {
        guard config == nil || config?.isSDKEnabled == true else {
            return nil
        }

        return sessionController.currentSession?.id.toString
    }

    /// Returns the current device identifier.
    @objc public func currentDeviceId() -> String? {
        return deviceId.hex
    }

    /// Forces the Embrace SDK to start a new session.
    /// - Note: If there was a session running, it will be ended before starting a new one.
    @objc public func startNewSession() {
        sessionLifecycle.startSession()
    }

    /// Force the Embrace SDK to stop the current session, if any.
    @objc public func endCurrentSession() {
        sessionLifecycle.endSession()
    }

    /// Called everytime the remote config changes
    @objc private func onConfigUpdated() {
        if let config = config {
            Embrace.logger.limits = InternalLogLimits(config: config)
        }
    }
}
