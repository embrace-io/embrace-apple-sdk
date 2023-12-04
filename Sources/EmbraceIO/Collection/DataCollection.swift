//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

final class DataCollection {
    let collectors: [Collector]
    let context: CollectorContext

    weak var crashReporter: CrashReporter?

    init(options: Embrace.Options) {
        collectors = CollectorFactory.addRequiredCollectors(to: options.collectors.unique)
        crashReporter = collectors.first { $0 is CrashReporter } as? CrashReporter

        context = CollectorContext(
            appId: options.appId,
            sdkVersion: EmbraceMeta.sdkVersion,
            filePathProvider: EmbraceFilePathProvider(appId: options.appId, appGroupIdentifier: options.appGroupId)
        )
    }

    func start() {
        // TODO: Should be threadsafe
        for collector in collectors {
            if let installedCollector = collector as? InstalledCollector {
                installedCollector.install(context: context)
            }

            collector.start()
        }
    }

    func stop() {
        // TODO: Should be threadsafe
        for collector in collectors {
            collector.stop()
        }
    }
}

private extension Array where Element == any Collector {
    var unique: [any Collector] {
        var unique = [String: Collector]()

        for collector in self {
            let typeName = String(describing: type(of: collector))
            guard unique[typeName] == nil else {
                continue
            }

            unique[typeName] = collector
        }

        return Array(unique.values)
    }
}
