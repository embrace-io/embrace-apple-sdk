//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import Security
import CommonCrypto
import CryptoKit

class EncryptionHelper {

    class func rsaEncrypt(publicKey: String, data: Data) -> RSA.Result? {
        guard let key = RSA.createKey(for: publicKey),
              RSA.isEncryptionPossible(forKey: key) else {
            return nil
        }

        return RSA.encrypt(data: data, key: key)
    }

    class func aesEncrypt(data: Data) -> AES.Result? {
        guard let key = AES.createRandomKey(),
              let iv = AES.createRandomIv() else {
            return nil
        }

        return AES.encrypt(data: data, key: key, iv: iv)
    }
}

struct RSA {

    struct Result {
        let algorithm = "RSA.PKCS1"
        let data: Data

        init(data: Data) {
            self.data = data
        }
    }

    static func createKey(for publicKey: String) -> SecKey? {
        var createKeyError: Unmanaged<CFError>?

        let attributes = [
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA
        ] as CFDictionary

        guard let keyData = Data(base64Encoded: publicKey),
              let key = SecKeyCreateWithData(keyData as CFData, attributes, &createKeyError) else {

            if let createKeyError = createKeyError {
                Embrace.logger.debug("Error creating public key \(publicKey)!:\n\(createKeyError)")
            } else {
                Embrace.logger.debug("Error creating public key \(publicKey)!")
            }
            return nil
        }

        return key
    }

    static func isEncryptionPossible(forKey key: SecKey) -> Bool {
        guard SecKeyIsAlgorithmSupported(key, .encrypt, .rsaEncryptionPKCS1) else {
            Embrace.logger.debug("PKCS1 encryption not supported!")
            return false
        }

        return true
    }

    static func encrypt(data: Data, key: SecKey) -> Result? {
        var error: Unmanaged<CFError>?
        guard let encryptedData = SecKeyCreateEncryptedData(
            key,
            .rsaEncryptionPKCS1,
            data as CFData,
            &error
        ) as Data? else {
            if let error = error {
                Embrace.logger.debug("Encryption error:\n\(error)")
            }
            return nil
        }

        return Result(data: encryptedData)
    }
}

struct AES {

    struct Result {
        let algorithm = "aes-256-cbc"
        let data: Data
        let key: Data
        let iv: Data

        init(data: Data, key: Data, iv: Data) {
            self.data = data
            self.key = key
            self.iv = iv
        }
    }

    static func createRandomKey() -> Data? {
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { bytes in
            Data(bytes)
        }

        return keyData
    }

    static func createRandomIv() -> Data? {
        return randomData(length: kCCBlockSizeAES128)
    }

    static func encrypt(data: Data, key: Data, iv: Data) -> Result? {

        var outLength = Int(0)
        var outBytes = [UInt8](repeating: 0, count: data.count + kCCBlockSizeAES128)
        var status = CCCryptorStatus(kCCSuccess)

        data.withUnsafeBytes { (dataBytes: UnsafeRawBufferPointer) in
            key.withUnsafeBytes { (keyBytes: UnsafeRawBufferPointer)  in
                iv.withUnsafeBytes { (ivBytes: UnsafeRawBufferPointer) in
                    guard let dataPointer = dataBytes.baseAddress,
                          let keyPointer = keyBytes.baseAddress,
                          let ivPointer = ivBytes.baseAddress else {
                        status = -1
                        return
                    }

                    status = CCCrypt(
                        CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmAES128),
                        CCOptions(kCCOptionPKCS7Padding),
                        keyPointer,
                        key.count,
                        ivPointer,
                        dataPointer,
                        data.count,
                        &outBytes,
                        outBytes.count,
                        &outLength
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            return nil
        }

        return Result(
            data: Data(bytes: outBytes, count: outLength),
            key: key,
            iv: iv
        )
    }

    static func randomData(length: Int) -> Data? {
        var data = Data(count: length)
        let status: Int32 = data.withUnsafeMutableBytes { (mutableBytes: UnsafeMutableRawBufferPointer) in
            guard let pointer = mutableBytes.baseAddress else {
                return -1
            }

            return SecRandomCopyBytes(kSecRandomDefault, length, pointer)
        }

        guard status == 0 else {
            return nil
        }

        return data
    }
}
