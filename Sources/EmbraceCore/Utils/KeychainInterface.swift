//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

protocol KeychainInterface {
    func valueFor(service: CFString, account: CFString) -> (value: String?, status: OSStatus)
    func setValue(service: CFString, account: CFString, value: String, completion: @escaping @Sendable (OSStatus) -> Void)
    func deleteValue(service: CFString, account: CFString) -> OSStatus
}

class DefaultKeychainInterface: KeychainInterface {
    private let queue: DispatchQueue

    init(queue: DispatchQueue = DispatchQueue(label: "com.embrace.keychainAccess", qos: .userInitiated)) {
        self.queue = queue
    }

    func valueFor(service: CFString, account: CFString) -> (value: String?, status: OSStatus) {
        let keychainQuery: NSMutableDictionary = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

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

    func setValue(
        service: CFString,
        account: CFString,
        value: String,
        completion: @escaping @Sendable (OSStatus) -> Void
    ) {
        /*
        
         Why Async in `setValue` but not in `valueFor`?
         -> The decision to make this method asynchronous, while keeping `valueFor` synchronous, is based on the nature of Keychain operations and their expected performance characteristics:
        
         `setValue` (Write Operations):
         * Writing to the Keychain (in this case using `SecItemAdd`) often requires coordination with the system's `securityd` process.
         * These tasks can occasionally take time, especially under system load or network conditions, which can block the calling thread.
         * Performing this on the Main Thread risks causing UI freezes or App Hangs, making it necessary to offload the operation to a background thread.
        
         `valueFor` (Read Operations):
         * Reading from the Keychain (in this case using `SecItemCopyMatching`) is generally faster because it doesn't modify the Keychain.
         * The system can return cached results for some queries, making read operations more predictable in terms of performance.
        
         */
        let serviceString = service as String
        let accountString = account as String
        queue.async { [serviceString, accountString] in
            guard let dataFromString = value.data(using: String.Encoding.utf8, allowLossyConversion: false) else {
                completion(errSecParam)
                return
            }

            let query: NSMutableDictionary = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: serviceString,
                kSecAttrAccount: accountString,
                kSecValueData: dataFromString
            ]

            // Add the new keychain item
            completion(SecItemAdd(query, nil))
        }
    }

    func deleteValue(service: CFString, account: CFString) -> OSStatus {
        let keychainQuery: NSMutableDictionary = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]

        return SecItemDelete(keychainQuery)
    }

}
