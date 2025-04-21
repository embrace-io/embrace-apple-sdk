//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCaptureService
import EmbraceCommonInternal
import EmbraceStorageInternal
import EmbraceUploadInternal
import EmbraceConfiguration

final class CaptureServices {

    @ThreadSafe
    var services: [CaptureService]

    var context: CrashReporterContext
    weak var crashReporter: CrashReporter?

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
        services = CaptureServiceFactory.addRequiredServices(to: options.services.unique)

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
        crashReporter = options.crashReporter

        // upload action for crash reports
        if let crashReporter = options.crashReporter {
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

            if crashReporter.disableMetricKitReports == false {
                services.append(MetricKitCrashCaptureService())
            }
        }

        // pass storage reference to capture services
        // that generate resources
        for service in services {
            if let resourceService = service as? ResourceCaptureService {
                resourceService.handler = storage
            }
        }

        // subscribe to session start notification
        // to update the crash reporter with the new session id
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSessionStart),
            name: Notification.Name.embraceSessionDidStart,
            object: nil
        )
    }

    // for testing
    init(config: EmbraceConfigurable?, services: [CaptureService], context: CrashReporterContext) {
        self.config = config
        self.services = services
        self.context = context
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func install() {
        crashReporter?.install(context: context, logger: Embrace.logger)

        for service in services {
            service.install(otel: Embrace.client, logger: Embrace.logger)
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
        }
    }
}

private extension Array where Element == CaptureService {
    var unique: [CaptureService] {
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
