//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

extension Embrace {

    // this is temp just so we can test collecting and storing resources into the database
    // TODO: Replace this with intended otel way of collecting resources
    public func addResource(key: String, value: String) throws {
        try storage.addResource(
            key: key,
            value: value,
            resourceType: .process,
            resourceTypeId: ProcessIdentifier.current.hex
        )
    }

    public func addResource(key: String, value: Int) throws {
        try addResource(key: key, value: String(value))
    }

    public func addResource(key: String, value: Double) throws {
        try addResource(key: key, value: String(value))
    }

}
