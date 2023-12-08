//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommon

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
