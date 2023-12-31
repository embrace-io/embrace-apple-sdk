//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

final class CaptureServices {

    @ThreadSafe
    var services: [CaptureService]
    let context: CaptureServiceContext

    weak var crashReporter: CrashReporter?

    init(options: Embrace.Options) {
        services = CaptureServiceFactory.addRequiredServices(to: options.services.unique)
        context = CaptureServiceContext(
            appId: options.appId,
            sdkVersion: EmbraceMeta.sdkVersion,
            filePathProvider: EmbraceFilePathProvider(appId: options.appId, appGroupIdentifier: options.appGroupId)
        )

        crashReporter = services.first { $0 is CrashReporter } as? CrashReporter
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
