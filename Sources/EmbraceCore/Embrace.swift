//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceConfigInternal
    import EmbraceOTelInternal
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
@objc public class Embrace: NSObject {

    /**
     Returns the current `Embrace` client.
    
     This will be `nil` until the `setup` method is called, or if the setup process fails.
     */
    @objc public internal(set) static var client: Embrace?

    /// The `Embrace.Options` that were used to configure the SDK.
    @objc public private(set) var options: Embrace.Options

    /// Returns the current state of the SDK.
    @objc public private(set) var state: EmbraceSDKState = .notInitialized

    /// Returns whether the SDK was started.
    @available(*, deprecated, message: "Use `state` instead.")
    @objc public var started: Bool {
        return state == .started
    }

    /// Returns the `DeviceIdentifier` used by Embrace for the current device.
    public private(set) var deviceId: DeviceIdentifier

    /// Used to control the verbosity level of the Embrace SDK console logs.
    @objc public var logLevel: LogLevel = .error {
        didSet {
            Embrace.logger.level = logLevel
        }
    }

    /// Returns true if the SDK is started and was not disabled through remote configurations.
    @objc public var isSDKEnabled: Bool {
        let remoteConfigEnabled = config.isSDKEnabled
        return state == .started && remoteConfigEnabled
    }

    /// Returns the version of the Embrace SDK.
    @objc public class var sdkVersion: String {
        return EmbraceMeta.sdkVersion
    }

    /// Returns the current `MetadataHandler` used to store resources and session properties.
    @objc public let metadata: MetadataHandler

    /// Returns the current `StartupInstrumentation` used to instrument the app startup process.
    @objc public let startupInstrumentation: StartupInstrumentation

    /// Holds the experiments and feature flags tracked during this process.
    package let experiments: ExperimentsHandler

    let metricKit: MetricKitHandler

    let config: EmbraceConfig
    let storage: EmbraceStorage
    let upload: EmbraceUpload?
    let captureServices: CaptureServices
    let captureServicesGroup: DispatchGroup

    let logController: LogControllable

    let sessionController: SessionController
    let sessionLifecycle: SessionLifecycle

    let spanEventsLimiter: SpanEventsLimiter

    let otelResources: Resource?

    let processingQueue = DispatchQueue(
        label: "com.embrace.processing",
        qos: .utility,
        autoreleaseFrequency: .workItem,
        target: .global(qos: .utility)
    )

    private static let _syncLock = ReadWriteLock()
    static let notificationCenter: NotificationCenter = NotificationCenter()

    static var logger: DefaultInternalLogger = DefaultInternalLogger(
        pendingFilePath: EmbraceFileSystem.pendingLogsURL,
        criticalFilePath: EmbraceFileSystem.criticalLogsURL
    )

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
        return try setup(options: options, otelResources: nil)
    }

    @discardableResult
    package static func setup(options: Embrace.Options, otelResources: Resource?) throws -> Embrace {

        if !Thread.isMainThread {
            throw EmbraceSetupError.invalidThread("Embrace must be setup on the main thread")
        }

        if ProcessInfo.processInfo.isSwiftUIPreview {
            throw EmbraceSetupError.initializationNotAllowed("Embrace cannot be initialized on SwiftUI Previews")
        }

        let setupTime = Date()

        let span = EmbraceMetricKitSpan.begin(name: "sdk-setup", force: true)

        return try _syncLock.lockedForWriting {
            defer { span.end() }

            if let client = client {
                Embrace.logger.warning("Embrace was already initialized!")
                return client
            }

            EMBStartupTracker.shared().sdkSetupStartTime = setupTime

            try options.validate()

            client = try Embrace(options: options, otelResources: otelResources)
            if let client = client {
                EMBStartupTracker.shared().sdkSetupEndTime = Date()
                Embrace.logger.startup("Embrace SDK setup finished")

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

    init(
        options: Embrace.Options,
        logControllable: LogControllable? = nil,
        embraceStorage: EmbraceStorage? = nil,
        embraceUpload: EmbraceUpload? = nil,
        otelResources: Resource? = nil
    ) throws {

        self.options = options
        self.logLevel = options.logLevel
        self.otelResources = otelResources

        // retrieve device identifier
        self.deviceId = EmbraceIdentifier.retrieveDeviceId(fileURL: EmbraceFileSystem.deviceIdURL)

        // initialize remote configuration
        self.config = Embrace.createConfig(options: options, deviceId: deviceId)

        // Take the previous launch's critical logs (and remove any orphan pending-logs file) before anything here can
        // log a `.critical`: `createUpload` and both stores' loads can, and the first one replaces the previous
        // launch's file with this one's.
        let previousCriticalLogs = UnsentDataHandler.takeCriticalLogs(
            fileUrl: EmbraceFileSystem.criticalLogsURL,
            pendingFileUrl: EmbraceFileSystem.pendingLogsURL
        )

        // initialize upload module
        self.upload = try embraceUpload ?? Embrace.createUpload(options: options, deviceId: deviceId.stringValue, configuration: config.configurable)

        // send critical logs from previous session
        UnsentDataHandler.sendCriticalLogs(previousCriticalLogs, upload: upload)

        // initialize storage module
        self.storage = try embraceStorage ?? Embrace.createStorage(options: options, configuration: config.configurable)

        // Persist the critical resources before any other storage operation (only the store load runs before them).
        // The backend drops payloads without them, and since the storage context is serial,
        // enqueuing them first guarantees every later read sees them without blocking this thread.
        let criticalResources = AppInfoCaptureService.criticalResources.merging(DeviceInfoCaptureService.criticalResources) { current, _ in current }
        storage.addCriticalResources(
            criticalResources,
            processId: ProcessIdentifier.current
        )

        // Create a group for the services, this group leaves once the services are started.
        self.captureServicesGroup = DispatchGroup()
        self.captureServicesGroup.enter()

        // initialize capture services
        self.captureServices = try CaptureServices(
            options: options,
            config: config.configurable,
            storage: storage,
            upload: upload
        )

        // initialize session controller
        self.sessionController = SessionController(storage: storage, upload: upload, config: config)
        self.sessionLifecycle = Embrace.createSessionLifecycle(controller: sessionController)

        // initialize span events limiter
        self.spanEventsLimiter = SpanEventsLimiter(
            spanEventsLimits: config.spanEventsLimits,
            configNotificationCenter: Embrace.notificationCenter
        )

        // initialize metadata handler
        self.metadata = MetadataHandler(storage: storage, sessionController: sessionController)
        self.metricKit = MetricKitHandler()

        // initialize experiments handler
        self.experiments = ExperimentsHandler(
            storage: storage,
            experimentsLimits: config.experimentsLimits,
            configNotificationCenter: Embrace.notificationCenter
        )

        // initialize startup instrumentation
        self.startupInstrumentation = StartupInstrumentation()

        // initialize log controller
        var logController: LogController?
        if let logControllable = logControllable {
            self.logController = logControllable
        } else {
            let controller = LogController(
                storage: storage,
                upload: upload,
                controller: sessionController
            )
            logController = controller
            self.logController = controller
        }

        super.init()

        captureServices.addMetricKitServices(
            payloadProvider: metricKit,
            metadataFetcher: storage,
            stateProvider: self
        )

        // The stores load asynchronously (see `CoreDataWrapper`). The SDK can't work without them,
        // so if either fails, report it and stop the SDK (see `storeFailedToLoad`).
        storage.coreData.onInitialLoad { [weak self] error in
            if error != nil {
                self?.storeFailedToLoad("storage")
            }
        }
        upload?.onCacheLoaded { [weak self] error in
            if error != nil {
                self?.storeFailedToLoad("upload cache")
            }
        }

        sessionController.sdkStateProvider = self
        logController?.sdkStateProvider = self
        logController?.privateLogger = self

        // the session span and every log report the experiments tracked so far
        sessionController.experiments = experiments
        logController?.experiments = experiments

        // setup otel
        EmbraceOTel.setup(
            spanProcessors: buildProcessors(
                for: storage,
                sessionController: sessionController,
                customExporter: options.export,
                customProcessors: options.processors?.compactMap { $0.processor },
                sdkStateProvider: self,
                useNewStorageForSpanEvents: config.useNewStorageForSpanEvents,
                resource: otelResources
            ),
            resource: otelResources
        )

        let logBatcher = DefaultLogBatcher(
            repository: storage,
            logLimits: .init(),
            delegate: self.logController
        )

        sessionController.setLogBatcher(logBatcher)

        let logSharedState = DefaultEmbraceLogSharedState.create(
            storage: self.storage,
            batcher: logBatcher,
            processors: options.processors?.compactMap { $0.logProcessor } ?? [],
            exporter: options.export?.logExporter,
            sdkStateProvider: self,
            resource: otelResources
        )

        EmbraceOTel.setup(logSharedState: logSharedState)
        sessionLifecycle.setup()
        Embrace.logger.otel = self

        // startup tracking
        startupInstrumentation.otel = self

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
    /// - Note: This method won't do anything if the Embrace SDK was already started or stopped, or if it was disabled via the remote
    ///         configurations. A store that fails to load stops the SDK (see `storeFailedToLoad`).
    /// - Returns: The `Embrace` client instance.
    @discardableResult
    @objc public func start() throws -> Embrace {
        guard Thread.isMainThread else {
            throw EmbraceSetupError.invalidThread("Embrace must be started on the main thread")
        }

        EMBStartupTracker.shared().sdkStartStartTime = Date()
        let span = EmbraceMetricKitSpan.begin(name: "sdk-start", force: true)

        if EMBStartupTracker.shared().appDidFinishLaunchingEndTime != nil || EMBStartupTracker.shared().appFirstDidBecomeActiveTime != nil {
            Embrace.logger.error("Embrace SDK should be started before the app is launched and becomes active. This is required for the startup instrumentation to work.")
        }

        // must be called on main thread in order to fetch the app state
        sessionLifecycle.setup()

        return Embrace._syncLock.lockedForWriting {

            defer { span.end() }

            guard state == .initialized else {
                Embrace.logger.warning("The Embrace SDK can only be started once!")
                return self
            }

            guard config.isSDKEnabled else {
                Embrace.logger.warning("Embrace can't start when disabled!")
                return self
            }

            let processStartSpan = createProcessStartSpan()
            defer { processStartSpan.end() }

            recordSpan(
                name: "emb-sdk-start-process",
                parent: processStartSpan,
                type: .performance
            ) { _ in

                state = .started

                startupInstrumentation.buildMainSpans()
                sessionLifecycle.startSession()
                captureServices.install()

                // save latest session in memory before its sent and deleted
                // this will be used to link metric kit payloads to the session
                storage.fetchLatestSession { [self] session in
                    // the SDK may have been stopped meanwhile (e.g. one of its stores failed to load)
                    guard isSDKEnabled else {
                        return
                    }
                    metricKit.lastSession = session
                    metricKit.install()
                }

                // WARNING: This is dangerous as it calls out to external code.
                self.captureServices.start()

                // now that services are started, and critical pieces are in place,
                // notify anyone who cares.
                self.captureServicesGroup.leave()

                self.processingQueue.async { [weak self] in
                    self?.sendUnsentData()
                }

                // retry any remaining cached upload data
                self.upload?.retryCachedData()

                if let appId = options.appId {
                    Embrace.logger.startup("Embrace SDK started successfully with key: \(appId)")
                } else {
                    Embrace.logger.startup("Embrace SDK started successfully!")
                }
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
    @objc public func stop() throws -> Embrace {
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

            stopNoLock()

            Embrace.logger.startup("Embrace SDK stopped successfully!")

            return self
        }
    }

    /// Removes old-version data, then starts sending the data left by earlier launches and adds the otel resources.
    /// Called on `processingQueue` when the SDK starts. If either store failed to load, nothing is sent and the
    /// otel resources aren't added either; the old-version data is still removed.
    /// - Parameter completion: Called once the unsent data was handed to the upload module, or skipped.
    ///   It doesn't wait for the otel resources to be added.
    func sendUnsentData(completion: (() -> Void)? = nil) {
        // remove old versions data (files only, it doesn't need the stores)
        cleanUpOldVersionsData()

        // The data from earlier launches is read from the storage and uploaded through the upload cache, and either
        // may still be loading. If one failed to load, everything is kept for a later launch instead: without the
        // storage, crash reports would be sent without the resources the backend requires, and deleted; without the
        // upload cache, nothing is sent but the metadata the unsent logs need would be cleaned up.
        // This waits for the loads on the calling queue, which must not be the main one.
        guard storage.coreData.isStoreLoaded, upload?.isCacheLoaded ?? true else {
            Embrace.logger.warning("Not sending the data from earlier launches: one of the SDK's stores isn't loaded.")
            completion?()
            return
        }

        // fetch crash reports and link them to sessions
        // then upload them
        UnsentDataHandler.sendUnsentData(
            storage: storage,
            upload: upload,
            otel: self,
            logController: logController,
            currentSessionId: sessionController.currentSession?.id,
            crashReporter: captureServices.crashReporter,
            completion: completion
        )

        // add otel resources as metadata
        addOtelResources()
    }

    /// Must be called on the main thread while holding `_syncLock` for writing, with the SDK started.
    private func stopNoLock() {
        state = .stopped

        sessionLifecycle.stop()
        sessionController.clear()
        captureServices.stop()
        metricKit.uninstall()
    }

    /// Stops the SDK for the rest of the process because one of its stores failed to load.
    /// On the main thread, the SDK is stopped if it started, or moved to `.stopped` if it hadn't, so `start()`
    /// won't start it. A `start()` that runs before then starts the SDK, which is then stopped right away,
    /// the same as when a store fails after `start()`.
    ///
    /// The failure is reported with a critical log (the store also logs one with the load error).
    func storeFailedToLoad(_ store: String) {
        Embrace.logger.critical("Embrace SDK stopped because its \(store) failed to load")

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            Embrace._syncLock.lockedForWriting {
                switch self.state {
                case .started:
                    self.stopNoLock()
                case .initialized:
                    self.state = .stopped
                default:
                    break
                }
            }
        }
    }

    /// Returns the current session identifier, if any.
    @objc public func currentSessionId() -> String? {
        guard isSDKEnabled else {
            return nil
        }

        return sessionController.currentSession?.idRaw
    }

    /// Returns the current device identifier.
    @objc public func currentDeviceId() -> String? {
        return deviceId.stringValue
    }

    /// Forces the Embrace SDK to start a new session.
    /// - Note: If there was a session running, it will be ended before starting a new one.
    /// - Note: This method won't do anything if the SDK is stopped.
    @objc public func startNewSession() {
        guard isSDKEnabled else {
            return
        }

        processingQueue.async {
            self.sessionLifecycle.startSession()
        }
    }

    /// Forces the Embrace SDK to stop the current session, if any.
    /// - Note: This method won't do anything if the SDK is stopped.
    @objc public func endCurrentSession() {
        guard isSDKEnabled else {
            return
        }

        processingQueue.async {
            self.sessionLifecycle.endSession()
        }
    }

    /// Call this if you want the Embrace SDK to clear the upload cache data on the next launch.
    @objc public func resetUploadCache() {
        Embrace.resetUploadCache = true
    }

    /// Called every time the remote config changes
    @objc private func onConfigUpdated() {
        Embrace.logger.limits = config.internalLogLimits
        Embrace.client?.logController.limits = config.logsLimits

        if !config.isSDKEnabled {
            Embrace.logger.debug("SDK was disabled")
            captureServices.stop()
        }
    }
}
