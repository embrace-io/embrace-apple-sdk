//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommon
import EmbraceCrash

enum CollectorFactory { }

extension CollectorFactory {

    static var requiredCollectors: [Collector] {
        return [
            AppInfoCollector(),
            DeviceInfoCollector()
        ]
    }

    static func addRequiredCollectors(to collectors: [Collector]) -> [Collector] {
        return collectors + requiredCollectors
    }
}

extension CollectorFactory {

    #if os(iOS)
    static var platformCollectors: [Collector] {
        return [EmbraceCrashReporter()]
    }
    #elseif os(tvOS)
    static var platformCollectors: [Collector] {
        return [EmbraceCrashReporter()]
    }
    #else
    static var platformCollectors: [Collector] {
        return []
    }
    #endif

}
