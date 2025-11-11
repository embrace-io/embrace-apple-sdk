//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import Security

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

class KeychainAccess: @unchecked Sendable {

    static let kEmbraceKeychainService = "io.embrace.keys"
    static let kEmbraceDeviceId = "io.embrace.deviceid_v3"

    private init() {}

    nonisolated(unsafe)
        internal static var keychain: EmbraceMutex<KeychainInterface> = EmbraceMutex(DefaultKeychainInterface())

    static var deviceId: UUID {
        // fetch existing id
        let pair = keychain.safeValue.valueFor(
            service: kEmbraceKeychainService as CFString,
            account: kEmbraceDeviceId as CFString
        )

        if let _deviceId = pair.value {
            if let uuid = UUID(uuidString: _deviceId) {
                return uuid
            }
            Embrace.logger.error("Failed to construct device id from keychain")
        }

        // generate new id
        let newId = UUID()
        keychain.safeValue.setValue(
            service: kEmbraceKeychainService as CFString,
            account: kEmbraceDeviceId as CFString,
            value: newId.uuidString
        ) { status in
            if status != errSecSuccess {
                if let err = SecCopyErrorMessageString(status, nil) {
                    Embrace.logger.error("Write failed: \(err)")
                }
            }
        }

        return newId
    }
}
