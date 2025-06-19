//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCaptureService
import EmbraceCommonInternal
import EmbraceStorageInternal
#endif
import OpenTelemetryApi

protocol ResourceCaptureServiceHandler: AnyObject {
    func addRequiredResources(_ map: [String: String])
}

class ResourceCaptureService: CaptureService {
    weak var handler: ResourceCaptureServiceHandler?

    func addRequiredResources(_ map: [String: String]) {
        handler?.addRequiredResources(map)
    }
}

extension EmbraceStorage: ResourceCaptureServiceHandler {
    func addRequiredResources(_ map: [String: String]) {
        addRequiredResources(map, processId: .current)
    }
}
