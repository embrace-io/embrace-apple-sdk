//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
#endif

extension LogType {
    public static let networkCapture = LogType(system: "network_capture")
}

public extension LogSemantics {
    struct NetworkCapture {
        public static let keyUrl = "url"
        public static let keyEncryptionMechanism = "encryption-mechanism"
        public static let keyEncryptedPayload = "encrypted-payload"
        public static let keyPayloadAlgorithm = "payload-algorithm"
        public static let keyEncryptedKey = "encrypted-key"
        public static let keyKeyAlgorithm = "key-algorithm"
        public static let keyAesIv = "aes-iv"
    }
}
