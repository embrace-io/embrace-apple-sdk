//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceStorage

final class CaptureServices {

    @ThreadSafe
    var services: [CaptureService]
    let context: CaptureServiceContext

    weak var crashReporter: CrashReporter?

    init(options: Embrace.Options) throws {
        services = CaptureServiceFactory.addRequiredServices(to: options.services.unique)
        context = CaptureServiceContext(
            appId: options.appId,
            sdkVersion: EmbraceMeta.sdkVersion,
            filePathProvider: EmbraceFilePathProvider(appId: options.appId, appGroupIdentifier: options.appGroupId)
        )

        let crashReporters = services
            .filter({ $0 is CrashReporter })
            .compactMap({ $0 as? any CrashReporter })

        guard crashReporters.count <= 1 else {
            throw EmbraceSetupError.invalidOptions("Only one CrashReporter is allowed at most")
        }

        crashReporter = crashReporters.first

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
        for service in services {
            if let installedService = service as? InstalledCaptureService {
                installedService.install(context: context)
            }

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
            crashReporter?.currentSessionId = session.id
        }
    }
}

private extension Array where Element == any CaptureService {
    var unique: [any CaptureService] {
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
