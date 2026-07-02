//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

extension EmbraceType {
    public static let networkCapture = EmbraceType(system: "network_capture")
}

extension LogSemantics {
    public struct NetworkCapture {
        public static let keyUrl = "url"
        public static let keyEncryptionMechanism = "encryption-mechanism"
        public static let keyEncryptedPayload = "encrypted-payload"
        public static let keyPayloadAlgorithm = "payload-algorithm"
        public static let keyEncryptedKey = "encrypted-key"
        public static let keyKeyAlgorithm = "key-algorithm"
        public static let keyAesIv = "aes-iv"
    }
}
