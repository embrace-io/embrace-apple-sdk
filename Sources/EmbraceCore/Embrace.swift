//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceCommonInternal
    import EmbraceConfigInternal
    import EmbraceStorageInternal
    import EmbraceUploadInternal
    import EmbraceObjCUtilsInternal
#endif

/// Main class used to interact with the Embrace SDK.
///
/// To start the SDK you first need to configure it using an `Embrace.Options` instance passed in the `setup` static method.
/// Once the SDK is setup, you can start it by calling the `start` instance method.
///
/// **Please note that even if you setup the SDK, an Embrace session will not begin until `start` is called. This means data may not be correctly attached to that session.**
///
/// Example:
/// ```swift
/// import EmbraceIO
///
/// let options = Embrace.Options(appId: "appId", platform: .iOS)
/// try Embrace.setup(options: options)
/// try Embrace.client?.start()
/// ```
public class Embrace {

    /**
     Returns the current `Embrace` client.
    
     This will be `nil` until the `setup` method is called, or if the setup process fails.
     */
    public internal(set) static var client: Embrace?

    /// The `Embrace.Options` that were used to configure the SDK.
    public private(set) var options: Embrace.Options

    /// Returns the current state of the SDK.
    public private(set) var state: EmbraceSDKState = .notInitialized

    /// Returns the `DeviceIdentifier` used by Embrace for the current device.
    public private(set) var deviceId: EmbraceIdentifier

    /// Used to control the verbosity level of the Embrace SDK console logs.
    public var logLevel: LogLevel = .error {
        didSet {
            Embrace.logger.level = logLevel
        }
    }

    /// Returns true if the SDK is started and was not disabled through remote configurations.
    public var isSDKEnabled: Bool {
        let remoteConfigEnabled = config.isSDKEnabled
        return state == .started && remoteConfigEnabled
    }

    /// Returns the version of the Embrace SDK.
    public class var sdkVersion: String {
        return EmbraceMeta.sdkVersion
    }

    /// Returns the current `EmbraceOTelSignalsHandler` used to generate spans and logs.
    public let otel: DefaultOTelSignalsHandler

    /// Returns the current `MetadataHandler` used to store resources and session properties.
    public let metadata: MetadataHandler

    /// Returns the current `StartupInstrumentation` used to instrument the app startup process.
    public let startupInstrumentation: StartupInstrumentation

    let metricKit: MetricKitHandler

    let config: EmbraceConfig
    let storage: EmbraceStorage
    let upload: EmbraceUpload?
    let captureServices: CaptureServices

    let logController: LogController

    let sessionController: SessionController
    let sessionLifecycle: SessionLifecycle

    let processingQueue = DispatchQueue(
        label: "com.embrace.processing",
        qos: .utility,
        autoreleaseFrequency: .workItem,
        target: .global(qos: .utility)
    )

    private static let _syncLock = ReadWriteLock()
    static let notificationCenter: NotificationCenter = NotificationCenter()

    static var logger: DefaultInternalLogger = DefaultInternalLogger(exportFilePath: EmbraceFileSystem.criticalLogsURL)

    /// Method used to configure the Embrace SDK.
    /// - Parameter options: `Embrace.Options` to be used by the SDK.
    /// - Throws: `EmbraceSetupError.invalidThread` if not called from the main thread.
    /// - Throws: `EmbraceSetupError.invalidAppId` if the provided `appId` is invalid.
    /// - Throws: `EmbraceSetupError.invalidAppGroupId` if the provided `appGroupId` is invalid.
    /// - Throws: `EmbraceSetupError.invalidOptions` when providing more than one `CrashReporter`.
    /// - Note: This method won't do anything if the Embrace SDK was already setup.
    /// - Returns: The `Embrace` client instance.
    @discardableResult
    public static func setup(options: Embrace.Options) throws -> Embrace {
        if !Thread.isMainThread {
            throw EmbraceSetupError.invalidThread("Embrace must be setup on the main thread")
        }

        if ProcessInfo.processInfo.isSwiftUIPreview {
            throw EmbraceSetupError.initializationNotAllowed("Embrace cannot be initialized on SwiftUI Previews")
        }

        let setupTime = Date()

        return try _syncLock.lockedForWriting {
            if let client = client {
                Embrace.logger.warning("Embrace was already initialized!")
                return client
            }

            EMBStartupTracker.shared().sdkSetupStartTime = setupTime

            try options.validate()

            client = try Embrace(options: options)
            if let client = client {
                EMBStartupTracker.shared().sdkSetupEndTime = Date()
                Embrace.logger.startup("Embrace SDK setup finished")

                return client
            } else {
                throw EmbraceSetupError.unableToInitialize("Unable to initialize Embrace.client")
            }
        }
    }

    deinit {
        Embrace.notificationCenter.removeObserver(self)
    }

    init(
        options: Embrace.Options,
        embraceStorage: EmbraceStorage? = nil
    ) throws {

        self.options = options
        self.logLevel = options.logLevel

        // retrieve device identifier
        self.deviceId = DeviceIdentifierProvider.retrieve(fileURL: EmbraceFileSystem.deviceIdURL)

        // initialize remote configuration
        self.config = Embrace.createConfig(options: options, deviceId: deviceId)

        // initialize upload module
        self.upload = try Embrace.createUpload(options: options, deviceId: deviceId.stringValue, configuration: config.configurable)

        // send critical logs from previous session
        UnsentDataHandler.sendCriticalLogs(fileUrl: EmbraceFileSystem.criticalLogsURL, upload: upload)

        // initialize storage module
        self.storage = try embraceStorage ?? Embrace.createStorage(options: options, configuration: config.configurable)

        // initialize session controller
        self.sessionController = SessionController(storage: storage, upload: upload, config: config)
        self.sessionLifecycle = Embrace.createSessionLifecycle(controller: sessionController)

        // initialize log controller
        self.logController = LogController(
            storage: storage,
            upload: upload,
            sessionController: sessionController,
            queue: processingQueue
        )

        // initialize otel handler
        self.otel = DefaultOTelSignalsHandler(
            storage: storage,
            sessionController: sessionController,
            logController: self.logController,
            limiter: DefaultOtelSignalsLimiter(
                spanEventTypeLimits: config.spanEventTypeLimits,
                logSeverityLimits: config.logSeverityLimits,
                configNotificationCenter: Embrace.notificationCenter
            )
        )

        // initialize capture services
        self.captureServices = try CaptureServices(
            options: options,
            config: config.configurable,
            storage: storage,
            upload: upload,
            otel: self.otel
        )

        // initialize metadata handler
        self.metadata = MetadataHandler(storage: storage, sessionController: sessionController)
        self.metricKit = MetricKitHandler()

        // initialize startup instrumentation
        self.startupInstrumentation = StartupInstrumentation()

        // metrick kit
        captureServices.addMetricKitServices(
            payloadProvider: metricKit,
            metadataFetcher: storage,
            stateProvider: self
        )

        // set providers
        sessionController.sdkStateProvider = self
        sessionController.otel = self.otel
        logController.sdkStateProvider = self
        Embrace.logger.otel = self.otel

        // fetch app state
        sessionLifecycle.setup()

        // startup tracking
        startupInstrumentation.otel = self.otel
        EMBStartupTracker.shared().internalNotificationCenter = Embrace.notificationCenter
        EMBStartupTracker.shared().trackDidFinishLaunching()

        // config update event
        Embrace.notificationCenter.addObserver(
            self,
            selector: #selector(onConfigUpdated),
            name: .embraceConfigUpdated,
            object: nil
        )

        state = .initialized

        Embrace.logger.startup("Embrace SDK client initialized")
    }

    /// Method used to start the Embrace SDK.
    /// - Throws: `EmbraceSetupError.invalidThread` if not called from the main thread.
    /// - Note: This method won't do anything if the Embrace SDK was already started or if it was disabled via the remote configurations.
    /// - Returns: The `Embrace` client instance.
    @discardableResult
    public func start() throws -> Embrace {
        guard Thread.isMainThread else {
            throw EmbraceSetupError.invalidThread("Embrace must be started on the main thread")
        }

        EMBStartupTracker.shared().sdkStartStartTime = Date()

        // must be called on main thread in order to fetch the app state
        sessionLifecycle.setup()

        return Embrace._syncLock.lockedForWriting {
            guard state == .initialized else {
                Embrace.logger.warning("The Embrace SDK can only be started once!")
                return self
            }

            guard config.isSDKEnabled else {
                Embrace.logger.warning("Embrace can't start when disabled!")
                return self
            }

            // embrace process start spans
            let spans = createProcessStartSpans()
            defer {
                for span in spans {
                    span.end()
                }
            }

            // set sdk state
            state = .started

            // start instrumentation
            startupInstrumentation.buildMainSpans()
            sessionLifecycle.startSession()
            captureServices.install()

            // save latest session in memory before its sent and deleted
            // this will be used to link metric kit payloads to the session
            storage.fetchLatestSession { [self] session in
                metricKit.lastSession = session
                metricKit.install()
            }

            // WARNING: This is dangerous as it calls out to external code.
            self.captureServices.start()

            self.processingQueue.async { [weak self] in
                // fetch crash reports and link them to sessions
                // then upload them
                UnsentDataHandler.sendUnsentData(
                    storage: self?.storage,
                    upload: self?.upload,
                    otel: self?.otel,
                    logController: self?.logController,
                    currentSessionId: self?.sessionController.currentSession?.id,
                    crashReporter: self?.captureServices.crashReporter
                )

                // remove old versions data
                self?.cleanUpOldVersionsData()
            }

            // retry any remaining cached upload data
            self.upload?.retryCachedData()

            if let appId = options.appId {
                Embrace.logger.startup("Embrace SDK started successfully with key: \(appId)")
            } else {
                Embrace.logger.startup("Embrace SDK started successfully!")
            }

            EMBStartupTracker.shared().sdkStartEndTime = Date()

            return self
        }
    }

    /// Method used to stop the Embrace SDK from capturing and generating data.
    /// - Throws: `EmbraceSetupError.invalidThread` if not called from the main thread.
    /// - Note: This method won't do anything if the Embrace SDK was already stopped.
    /// - Note: The SDK can't be started again once stopped.
    /// - Returns: The `Embrace` client instance.
    @discardableResult
    public func stop() throws -> Embrace {
        guard Thread.isMainThread else {
            throw EmbraceSetupError.invalidThread("Embrace must be stopped on the main thread")
        }

        return Embrace._syncLock.lockedForWriting {
            guard state != .stopped else {
                Embrace.logger.warning("Embrace was already stopped!")
                return self
            }

            guard state == .started else {
                Embrace.logger.warning("Embrace was not started so it can't be stopped!")
                return self
            }

            state = .stopped

            sessionLifecycle.stop()
            sessionController.clear()
            captureServices.stop()
            metricKit.uninstall()

            Embrace.logger.startup("Embrace SDK stopped successfully!")

            return self
        }
    }

    /// Returns the current session identifier, if any.
    public func currentSessionId() -> String? {
        guard isSDKEnabled else {
            return nil
        }

        return sessionController.currentSession?.id.stringValue
    }

    /// Returns the current device identifier.
    public func currentDeviceId() -> String? {
        return deviceId.stringValue
    }

    /// Forces the Embrace SDK to start a new session.
    /// - Note: If there was a session running, it will be ended before starting a new one.
    /// - Note: This method won't do anything if the SDK is stopped.
    public func startNewSession() {
        guard isSDKEnabled else {
            return
        }

        processingQueue.async {
            self.sessionLifecycle.startSession()
        }
    }

    /// Forces the Embrace SDK to stop the current session, if any.
    /// - Note: This method won't do anything if the SDK is stopped.
    public func endCurrentSession() {
        guard isSDKEnabled else {
            return
        }

        processingQueue.async {
            self.sessionLifecycle.endSession()
        }
    }

    /// Call this if you want the Embrace SDK to clear the upload cache data on the next launch.
    public func resetUploadCache() {
        Embrace.resetUploadCache = true
    }

    /// Called every time the remote config changes
    @objc private func onConfigUpdated() {
        Embrace.logger.limits = config.internalLogLimits

        if !config.isSDKEnabled {
            Embrace.logger.debug("SDK was disabled")
            captureServices.stop()
        }
    }
}
