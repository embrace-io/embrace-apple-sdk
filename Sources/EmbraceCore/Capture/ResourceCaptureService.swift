//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCaptureService
import EmbraceCommonInternal
import EmbraceStorageInternal
import OpenTelemetryApi

protocol ResourceCaptureServiceHandler: AnyObject {
    func addResource(key: String, value: AttributeValue)
}

class ResourceCaptureService: CaptureService {
    weak var handler: ResourceCaptureServiceHandler?

    func addResource(key: String, value: AttributeValue) {
        handler?.addResource(key: key, value: value)
    }
}

extension EmbraceStorage: ResourceCaptureServiceHandler {
    func addResource(key: String, value: AttributeValue) {
        do {
            _ = try addMetadata(
                key: key,
                value: value.description,
                type: .requiredResource,
                lifespan: .process,
                lifespanId: ProcessIdentifier.current.hex
            )
        } catch {
            Embrace.logger.error("Failed to capture resource: \(error.localizedDescription)")
        }
    }
}
