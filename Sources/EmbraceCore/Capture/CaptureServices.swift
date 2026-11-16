//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCaptureService
    import EmbraceCommonInternal
    import EmbraceStorageInternal
    import EmbraceUploadInternal
    import EmbraceConfiguration
    import EmbraceSemantics
#endif

final class CaptureServices {

    private var _services: EmbraceMutex<[CaptureService]>
    var services: [CaptureService] {
        _services.safeValue
    }

    /// State of a capture service that was added after the SDK started.
    private struct LateServiceState {
        /// Identifier of the last session the service was notified about.
        var lastSessionId: String?
    }

    /// Capture services added after the SDK started, by identity.
    /// These are notified of the current session when added, so the notification of that same session
    /// must not reach them a second time.
    private let lateServices = EmbraceMutex([ObjectIdentifier: LateServiceState]())

    var context: CrashReporterContext
    var crashReporter: EmbraceCrashReporter?

    weak var config: EmbraceConfigurable?
    weak var otel: InternalOTelSignalsHandler?
    weak var storage: EmbraceStorage?

    init(
        options: Embrace.Options,
        config: EmbraceConfigurable?,
        storage: EmbraceStorage?,
        upload: EmbraceUpload?,
        otel: InternalOTelSignalsHandler?
    ) throws {
        self.config = config
        self.otel = otel
        self.storage = storage

        // add required capture services
        // and remove duplicates
        _services = EmbraceMutex(CaptureServiceFactory.addRequiredServices(to: options.services.unique))

        // create context for crash reporter
        let partitionIdentifier = options.appId ?? EmbraceFileSystem.defaultPartitionId
        context = CrashReporterContext(
            appId: options.appId,
            sdkVersion: EmbraceMeta.sdkVersion,
            filePathProvider: EmbraceFilePathProvider(
                partitionId: partitionIdentifier
            ),
            notificationCenter: Embrace.notificationCenter
        )
        if let reporter = options.crashReporter {
            crashReporter = EmbraceCrashReporter(reporter: reporter, logger: Embrace.logger)
        }

        // upload action for crash reports
        if let crashReporter {
            crashReporter.onNewReport = { [weak crashReporter, weak storage, weak upload] report in
                var processId: EmbraceIdentifier? = nil
                if let reportProcessId = crashReporter?.processId {
                    processId = EmbraceIdentifier(stringValue: reportProcessId)
                }

                UnsentDataHandler.sendCrashLog(
                    report: report,
                    reporter: crashReporter,
                    session: nil,
                    storage: storage,
                    upload: upload,
                    otel: otel,
                    processId: processId
                )
            }
        }

        services.forEach { wire($0) }

        if let config {
            services.forEach { $0.onConfigUpdated(config) }
        }

        // subscribe to session start notification
        // to update the crash reporter with the new session id
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSessionStart),
            name: Notification.Name.embraceSessionPartDidStart,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSessionWillEnd),
            name: Notification.Name.embraceSessionPartWillEnd,
            object: nil
        )

        // Set the crash-reporter's user-session id when a new user session begins.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onUserSessionDidStart),
            name: Notification.Name.embraceUserSessionDidStart,
            object: nil
        )

        // Clear the crash-reporter's user-session id when the active user session ends.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onUserSessionDidEnd),
            name: Notification.Name.embraceUserSessionDidEnd,
            object: nil
        )

        Embrace.notificationCenter.addObserver(
            self,
            selector: #selector(onConfigUpdated),
            name: Notification.Name.embraceConfigUpdated,
            object: nil
        )
    }

    // for testing
    init(config: EmbraceConfigurable?, services: [CaptureService], context: CrashReporterContext) {
        self.config = config
        self._services = EmbraceMutex(services)
        self.context = context
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        Embrace.notificationCenter.removeObserver(self)
    }

    func addMetricKitServices(
        payloadProvider: MetricKitPayloadProvider?,
        metadataFetcher: EmbraceStorageMetadataFetcher?,
        stateProvider: EmbraceMetricKitStateProvider?
    ) {
        guard crashReporter?.disableMetricKitReports != true else {
            return
        }

        let options = MetricKitCaptureServiceOptions(
            payloadProvider: payloadProvider,
            metadataFetcher: metadataFetcher,
            stateProvider: stateProvider
        )

        _services.withLock {
            $0.append(MetricKitCrashCaptureService(options: options))
            $0.append(MetricKitHangCaptureService(options: options))
            $0.append(MetricKitMetricsCaptureService(options: options))
        }
    }

    /// Passes the internal dependencies to a capture service before it's installed.
    func wire(_ service: CaptureService) {
        // pass storage reference to capture services
        // that generate resources
        if let resourceService = service as? ResourceCaptureService {
            resourceService.handler = storage
        }

        // Ensure the hang service has the right config
        #if !os(watchOS) && !os(macOS)
            if let limits = config?.hangLimits, let hangService = service as? HangCaptureService {
                hangService.limits = limits
            }
        #endif
    }

    /// Whether a capture service of the same type as the given one was already added.
    func containsService(ofSameTypeAs service: CaptureService) -> Bool {
        let typeName = Self.typeName(of: service)
        return services.contains { Self.typeName(of: $0) == typeName }
    }

    /// Adds a capture service before the SDK started. It's installed and started with the rest.
    /// The service receives its internal dependencies, but it doesn't receive the current config.
    /// Callers must call `onConfigUpdated` on it.
    /// - Returns: `false` if a capture service of the same type was already added.
    @discardableResult
    func add(_ service: CaptureService) -> Bool {
        let typeName = Self.typeName(of: service)

        let added = _services.withLock { services in
            guard !services.contains(where: { Self.typeName(of: $0) == typeName }) else {
                return false
            }

            services.append(service)
            return true
        }

        guard added else {
            Embrace.logger.warning("A capture service of type \(typeName) was already added!")
            return false
        }

        wire(service)
        return true
    }

    /// Adds a capture service that was already installed after the SDK started, and notifies it of the current session.
    ///
    /// The service only joins the list once it's installed, so session notifications never reach it before that.
    /// Each session start is delivered to it once, even if the notification of `currentSession` arrives while it's being added.
    /// - Parameters:
    ///   - service: The installed capture service.
    ///   - currentSession: The session to notify the service about, if any.
    func addInstalled(_ service: CaptureService, currentSession: EmbraceSession?) {
        let id = ObjectIdentifier(service)

        // Tracked before it's visible in the list, so any session notification that can see it also deduplicates it.
        lateServices.withLock { $0[id] = LateServiceState() }
        _services.withLock { $0.append(service) }

        if let currentSession, shouldNotifySessionStart(service, sessionId: currentSession.id.stringValue) {
            service.onSessionStart()
        }
    }

    /// Whether a capture service has to be notified that the given session started.
    /// Capture services added before the SDK started are always notified.
    private func shouldNotifySessionStart(_ service: CaptureService, sessionId: String?) -> Bool {
        return lateServices.withLock { states in
            guard var state = states[ObjectIdentifier(service)], let sessionId else {
                return true
            }

            guard state.lastSessionId != sessionId else {
                return false
            }

            state.lastSessionId = sessionId
            states[ObjectIdentifier(service)] = state
            return true
        }
    }

    private static func typeName(of service: CaptureService) -> String {
        return String(describing: type(of: service))
    }

    func install() {
        crashReporter?.install(context: context)

        for service in services {
            service.install(otel: otel, logger: Embrace.logger)
        }
    }

    func start() {
        for service in services {
            service.start()
        }
    }

    func stop() {
        for service in services {
            service.stop()
        }
    }

    @objc func onSessionStart(notification: Notification) {
        let sessionId = (notification.object as? EmbraceSession)?.id.stringValue
        if let sessionId {
            crashReporter?.currentSessionId = sessionId
        }

        for service in services where shouldNotifySessionStart(service, sessionId: sessionId) {
            service.onSessionStart()
        }
    }

    @objc func onSessionWillEnd(notification: Notification) {
        for service in services { service.onSessionWillEnd() }
    }

    @objc func onUserSessionDidStart(notification: Notification) {
        if let userSession = notification.object as? EmbraceUserSession {
            crashReporter?.currentUserSessionId = userSession.id.stringValue
        }
    }

    @objc func onUserSessionDidEnd(notification: Notification) {
        crashReporter?.currentUserSessionId = nil
    }

    @objc func onConfigUpdated(notification: Notification) {
        guard let config = notification.object as? EmbraceConfigurable else {
            return
        }
        for service in services { service.onConfigUpdated(config) }
    }
}

extension Array where Element == CaptureService {
    fileprivate var unique: [CaptureService] {
        var unique = [String: CaptureService]()

        for service in self {
            let typeName = String(describing: type(of: service))
            guard unique[typeName] == nil else {
                continue
            }

            unique[typeName] = service
        }

        return Array(unique.values)
    }
}
