//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceStorage

protocol CaptureServiceResourceHandlerType {
    func addResource(key: String, value: String) throws
    func addResource(key: String, value: Int) throws
    func addResource(key: String, value: Double) throws
}

class CaptureServiceResourceHandler: NSObject, CaptureServiceResourceHandlerType {
    func addResource(key: String, value: String) throws {
        _ = try Embrace.client?.storage.addMetadata(
            MetadataRecord(
                key: key,
                value: .string(value),
                type: .requiredResource,
                lifespan: .process,
                lifespanId: ProcessIdentifier.current.hex
            )
        )
    }

    func addResource(key: String, value: Int) throws {
        _ = try Embrace.client?.storage.addMetadata(
            MetadataRecord(
                key: key,
                value: .int(value),
                type: .requiredResource,
                lifespan: .process,
                lifespanId: ProcessIdentifier.current.hex
            )
        )
    }

    func addResource(key: String, value: Double) throws {
        _ = try Embrace.client?.storage.addMetadata(
            MetadataRecord(
                key: key,
                value: .double(value),
                type: .requiredResource,
                lifespan: .process,
                lifespanId: ProcessIdentifier.current.hex
            )
        )
    }
}
