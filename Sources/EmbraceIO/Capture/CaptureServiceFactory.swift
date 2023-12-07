//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommon
import EmbraceCrash

enum CaptureServiceFactory { }

extension CaptureServiceFactory {

    static var requiredServices: [CaptureService] {
        return [
            AppInfoCaptureService(),
            DeviceInfoCaptureService()
        ]
    }

    static func addRequiredServices(to services: [CaptureService]) -> [CaptureService] {
        return services + requiredServices
    }
}

extension CaptureServiceFactory {
    #if os(iOS)
    static var platformCaptureServices: [CaptureService] {
        return [
            URLSessionCaptureService(),

            LowMemoryWarningCaptureService(),
            LowPowerModeCaptureService(),

            EmbraceCrashReporter()
        ]
    }
    #elseif os(tvOS)
    static var platformCaptureServices: [CaptureService] {
        return [EmbraceCrashReporter()]
    }
    #else
    static var platformCaptureServices: [CaptureService] {
        return []
    }
    #endif
}
