//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
import EmbraceStorageInternal
#endif

extension DeviceIdentifier {
    static let resourceKey = "emb.device_id"

    static func retrieve(from storage: EmbraceStorage?) -> DeviceIdentifier {
        // retrieve from storage
        if let storage = storage {
            if let resource = storage.fetchRequiredPermanentResource(key: resourceKey) {
                if let uuid = UUID(withoutHyphen: resource.value) {
                    return DeviceIdentifier(value: uuid)
                }

                Embrace.logger.warning("Failed to convert device.id back into a UUID. Possibly corrupted!")
            }
        }

        // fallback to retrieve from Keychain
        let uuid = KeychainAccess.deviceId
        let deviceId = DeviceIdentifier(value: uuid)

        storage?.addMetadata(
            key: resourceKey,
            value: deviceId.hex,
            type: .requiredResource,
            lifespan: .permanent
        )

        return deviceId
    }
}
