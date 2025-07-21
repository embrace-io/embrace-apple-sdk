//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCaptureService
#endif

public enum CaptureServiceFactory {}

extension CaptureServiceFactory {

    static var requiredServices: [CaptureService] {
        return [
            AppInfoCaptureService(),
            DeviceInfoCaptureService(),
        ]
    }

    static func addRequiredServices(to services: [CaptureService]) -> [CaptureService] {
        return services + requiredServices
    }
}
