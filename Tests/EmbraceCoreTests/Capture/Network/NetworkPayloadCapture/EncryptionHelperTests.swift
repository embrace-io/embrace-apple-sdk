import TestSupport
//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
import XCTest

@testable import EmbraceCore

class EncryptionHelperTests: XCTestCase {

    func test_rsa_validKey() {
        // given a valid public key
        let key = TestConstants.rsaSanitizedPublicKey

        // when encrypting data using rsa
        let result = EncryptionHelper.rsaEncrypt(publicKey: key, data: TestConstants.data)

        // then the encryption is successful
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.algorithm, "RSA.PKCS1")
    }

    func test_rsa_invalidKey() {
        // given an invalid public key
        let key = TestConstants.rsaPublicKey

        // when encrypting data using rsa
        let result = EncryptionHelper.rsaEncrypt(publicKey: key, data: TestConstants.data)

        // then the encryption is not successful
        XCTAssertNil(result)
    }

    func test_aes() {
        // when encrypting data using aes
        let result = EncryptionHelper.aesEncrypt(data: TestConstants.data)

        // then the encryption is not successful
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.algorithm, "aes-256-cbc")
    }
}
