//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceStorage

extension DeviceIdentifier {
    static let resourceKey = "emb.device_id"

    static func retrieve(from storage: EmbraceStorage?) -> DeviceIdentifier {
        // retrieve from storage
        if let storage = storage {
            do {
                if let resource = try storage.fetchRequriedPermanentResource(key: resourceKey) {
                    if let uuid = resource.uuidValue {
                        return DeviceIdentifier(value: uuid)
                    }

                    Embrace.logger.warning("Failed to convert device.id back into a UUID. Possibly corrupted!")
                }
            } catch let e {
                Embrace.logger.error("Failed to fetch device id from database \(e.localizedDescription)")
            }
        }

        // fallback to retrieve from Keychain
        let uuid = KeychainAccess.deviceId
        let deviceId = DeviceIdentifier(value: uuid)

        if let storage = storage {
            do {
                try storage.addMetadata(
                    key: resourceKey,
                    value: deviceId.hex,
                    type: .requiredResource,
                    lifespan: .permanent
                )
            } catch let e {
                Embrace.logger.error("Failed to add device id to database \(e.localizedDescription)")
            }
        }

        return deviceId
    }
}
