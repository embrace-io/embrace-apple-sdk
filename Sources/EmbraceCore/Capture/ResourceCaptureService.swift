//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCaptureService
    import EmbraceCommonInternal
    import EmbraceStorageInternal
    import EmbraceCrash
#endif

protocol ResourceCaptureServiceHandler: AnyObject {
    func addRequiredResources(_ map: [String: String])
}

struct ResourceCaptureServiceHandlerBox {
    weak var value: ResourceCaptureServiceHandler?
}

class ResourceCaptureService: CaptureService {
    private var data = EmbraceMutex([ResourceCaptureServiceHandlerBox]())
    
    func add(_ handler: ResourceCaptureServiceHandler?) {
        if let handler {
            data.withLock {
                $0.append(ResourceCaptureServiceHandlerBox(value: handler))
            }
        }
    }
    func addRequiredResources(_ map: [String: String]) {
        let handlers = data.safeValue
        for handler in handlers {
            handler.value?.addRequiredResources(map)
        }
    }
}

extension EmbraceStorage: ResourceCaptureServiceHandler {
    func addRequiredResources(_ map: [String: String]) {
        addRequiredResources(map, processId: .current)
    }
}

extension EmbraceCrashReporter: ResourceCaptureServiceHandler {
    func addRequiredResources(_ map: [String : String]) {
        mergeCrashInfo(map: map)
    }
}
