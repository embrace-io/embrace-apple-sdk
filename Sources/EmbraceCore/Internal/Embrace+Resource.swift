//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

extension Embrace {

    // this is temp just so we can test collecting and storing resources into the database
    // TODO: Formalize interface to expose lifecycle type (session, process, permanent) and make public
    func addResource(key: String, value: String) throws {
        try storage.addResource(
            key: key,
            value: value,
            resourceType: .process,
            resourceTypeId: ProcessIdentifier.current.hex
        )
    }

    func addResource(key: String, value: Int) throws {
        try addResource(key: key, value: String(value))
    }

    func addResource(key: String, value: Double) throws {
        try addResource(key: key, value: String(value))
    }
}
