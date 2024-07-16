//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCaptureService
import EmbraceCommonInternal
import EmbraceStorageInternal
import EmbraceUploadInternal

final class CaptureServices {

    @ThreadSafe
    var services: [CaptureService]

    var context: CrashReporterContext
    weak var crashReporter: CrashReporter?

    init(options: Embrace.Options, storage: EmbraceStorage?, upload: EmbraceUpload?) throws {
        // add required capture services
        // adn remove duplicates
        services = CaptureServiceFactory.addRequiredServices(to: options.services.unique)

        // create context for crash reporter
        context = CrashReporterContext(
            appId: options.appId,
            sdkVersion: EmbraceMeta.sdkVersion,
            filePathProvider: EmbraceFilePathProvider(appId: options.appId, appGroupIdentifier: options.appGroupId),
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

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func start() {
        crashReporter?.install(context: context, logger: Embrace.logger)

        for service in services {
            service.install(otel: Embrace.client, logger: Embrace.logger)
            service.start()
        }
    }

    func stop() {
        for service in services {
            service.stop()
        }
    }

    @objc func onSessionStart(notification: Notification) {
        if let session = notification.object as? SessionRecord {
            crashReporter?.currentSessionId = session.id.toString
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
