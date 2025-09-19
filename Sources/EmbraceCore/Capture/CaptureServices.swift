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
#endif

final class CaptureServices {

    private var _services: EmbraceMutex<[CaptureService]>
    var services: [CaptureService] {
        _services.safeValue
    }

    var context: CrashReporterContext
    var crashReporter: EmbraceCrashReporter?

    weak var config: EmbraceConfigurable?

    init(
        options: Embrace.Options,
        config: EmbraceConfigurable?,
        storage: EmbraceStorage?,
        upload: EmbraceUpload?
    ) throws {
        self.config = config

        // add required capture services
        // and remove duplicates
        _services = EmbraceMutex(CaptureServiceFactory.addRequiredServices(to: options.services.unique))

        // create context for crash reporter
        let partitionIdentifier = options.appId ?? EmbraceFileSystem.defaultPartitionId
        context = CrashReporterContext(
            appId: options.appId,
            sdkVersion: EmbraceMeta.sdkVersion,
            filePathProvider: EmbraceFilePathProvider(
                partitionId: partitionIdentifier,
                appGroupId: options.appGroupId
            ),
            notificationCenter: Embrace.notificationCenter
        )
        if let reporter = options.crashReporter {
            crashReporter = EmbraceCrashReporter(reporter: reporter, logger: Embrace.logger)
        }

        // upload action for crash reports
        if let crashReporter {
            crashReporter.onNewReport = { [weak crashReporter, weak storage, weak upload] report in
                UnsentDataHandler.sendCrashLog(
                    report: report,
                    reporter: crashReporter,
                    session: nil,
                    storage: storage,
                    upload: upload,
                    otel: Embrace.client
                )
            }
        }

        // pass storage reference to capture services
        // that generate resources
        for service in services {
            if let resourceService = service as? ResourceCaptureService {
                resourceService.handler = storage
            }
        }

        // Ensure the hang service has the right config
        if let limits = config?.hangLimits {
            services
                .compactMap { $0 as? HangCaptureService }
                .forEach { $0.limits = limits }
        }

        if let config {
            services.forEach { $0.onConfigUpdated(config) }
        }

        // subscribe to session start notification
        // to update the crash reporter with the new session id
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSessionStart),
            name: Notification.Name.embraceSessionDidStart,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSessionWillEnd),
            name: Notification.Name.embraceSessionWillEnd,
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
        guard crashReporter?.disableMetricKitReports == false else {
            return
        }

        _services.withLock {
            // crashes
            let crashOptions = MetricKitCrashCaptureService.Options(
                payloadProvider: payloadProvider,
                metadataFetcher: metadataFetcher,
                stateProvider: stateProvider
            )
            $0.append(MetricKitCrashCaptureService(options: crashOptions))

            // hangs
            let hangOptions = MetricKitHangCaptureService.Options(
                payloadProvider: payloadProvider,
                metadataFetcher: metadataFetcher,
                stateProvider: stateProvider
            )
            $0.append(MetricKitHangCaptureService(options: hangOptions))
        }
    }

    func install() {
        crashReporter?.install(context: context)

        for service in services {
            service.install(otel: Embrace.client, logger: Embrace.logger, metadata: Embrace.client?.metadata)
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
        if let session = notification.object as? EmbraceSession {
            crashReporter?.currentSessionId = session.idRaw
            for service in services { service.onSessionStart(session) }
        }
    }

    @objc func onSessionWillEnd(notification: Notification) {
        if let session = notification.object as? EmbraceSession {
            for service in services { service.onSessionWillEnd(session) }
        }
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
