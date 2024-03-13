//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCaptureService
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
            LowPowerModeCaptureService()
        ]
    }
    #elseif os(tvOS)
    static var platformCaptureServices: [CaptureService] {
        return []
    }
    #else
    static var platformCaptureServices: [CaptureService] {
        return []
    }
    #endif
}
