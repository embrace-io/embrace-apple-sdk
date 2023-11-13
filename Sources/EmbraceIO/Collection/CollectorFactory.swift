//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommon
import EmbraceCrash

enum CollectorFactory { }

extension CollectorFactory {

    static var requiredCollectors: [any Collector] {
        return [
            AppInfoCollector(),
            DeviceInfoCollector()
        ]
    }

    static func addRequiredCollectors(to collectors: [any Collector]) -> [any Collector] {
        return collectors + requiredCollectors
    }
}

extension CollectorFactory {

    #if os(iOS)
    static var platformCollectors: [any Collector] {
        return [EmbraceCrashReporter()]
    }
    #elseif os(tvOS)
    static var platformCollectors: [any Collector] {
        return [EmbraceCrashReporter()]
    }
    #else
    static var platformCollectors: [any Collector] {
        return []
    }
    #endif

}
