//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceStorage

class EmbraceDeviceId {

    static let resourceKey = "emb.device_id"

    private init() { }

    public static func retrieve(from storage: EmbraceStorage?) -> UUID {

        if let storage = storage {
            do {
                if let resource = try storage.fetchRequriedPermanentResource(key: resourceKey) {
                    if let deviceId = resource.uuidValue {
                        return deviceId
                    }

                    ConsoleLog.warning("Failed to convert device.id back into a UUID. Possibly corrupted!")
                }
            } catch let e {
                ConsoleLog.error("Failed to fetch device id from database \(e.localizedDescription)")
            }
        }

        let deviceId = KeychainAccess.deviceId

        if let storage = storage {
            do {
                try storage.addMetadata(
                    key: resourceKey,
                    value: deviceId.uuidString,
                    type: .requiredResource,
                    lifespan: .permanent
                )
            } catch let e {
                ConsoleLog.error("Failed to add device id to database \(e.localizedDescription)")
            }
        }

        return deviceId

    }

}
