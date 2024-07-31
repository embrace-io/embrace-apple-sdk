//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCaptureService

public enum CaptureServiceFactory { }

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
