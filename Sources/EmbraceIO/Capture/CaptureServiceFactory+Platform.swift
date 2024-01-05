//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCore
import EmbraceCommon
import EmbraceCrash

extension CaptureServiceFactory {
    #if os(iOS)
    static var platformCaptureServices: [CaptureService] {
        return [
            URLSessionCaptureService(),
            TapCaptureService(),

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
