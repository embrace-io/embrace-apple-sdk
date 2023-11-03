//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

protocol KeychainInterface {
    func valueFor(service: CFString, account: CFString) -> (value: String?, status: OSStatus)
    func setValue(service: CFString, account: CFString, value: String) -> OSStatus
    func deleteValue(service: CFString, account: CFString) -> OSStatus
}

class DefaultKeychainInterface: KeychainInterface {
    func valueFor(service: CFString, account: CFString) -> (value: String?, status: OSStatus) {
        let keychainQuery: NSMutableDictionary = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account, kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne]

        var dataTypeRef: AnyObject?

        // Search for the keychain items
        let status: OSStatus = SecItemCopyMatching(keychainQuery, &dataTypeRef)
        var contentsOfKeychain: String?

        if status == errSecSuccess {
            if let retrievedData = dataTypeRef as? Data {
                contentsOfKeychain = String(data: retrievedData, encoding: String.Encoding.utf8)
            }
        }

        return (contentsOfKeychain, status)
    }

    func setValue(service: CFString, account: CFString, value: String) -> OSStatus {
        guard let dataFromString = value.data(using: String.Encoding.utf8, allowLossyConversion: false) else {
            return errSecParam
        }

        let querry: NSMutableDictionary = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account, kSecValueData: dataFromString]

        // Add the new keychain item
        return SecItemAdd( querry, nil)
    }

    func deleteValue(service: CFString, account: CFString) -> OSStatus {
        let keychainQuery: NSMutableDictionary =  [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account]

        return SecItemDelete(keychainQuery)
    }

}
