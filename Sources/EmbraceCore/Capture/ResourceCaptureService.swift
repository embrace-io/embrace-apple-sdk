//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
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
                MetadataRecord(
                    key: key,
                    value: value,
                    type: .requiredResource,
                    lifespan: .process,
                    lifespanId: ProcessIdentifier.current.hex
                )
            )
        } catch {
            Embrace.logger.error("Failed to capture resource: \(error.localizedDescription)")
        }
    }
}
