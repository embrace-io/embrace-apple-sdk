//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension Dictionary where Key == String, Value == String {

    /// Encodes a `[String: String]` dictionary into a single `String` as a comma separated key value list
    /// Example: "key1,value1,key2,value2,key3,value3"
    func keyValueEncoded() -> String {
        guard self.count > 0 else {
            return ""
        }

        let keyValues = self.map { key, value in
            key.keyValueEncoded() + "," + value.keyValueEncoded()
        }

        return keyValues.joined(separator: ",")
    }

    /// Decodes a comma separated key value list into a `[String: String]`
    static func keyValueDecode(_ string: String) -> [String: String] {
        guard string.count > 0 else {
            return [:]
        }

        let array = string.components(separatedBy: ",")
        var result = [String: String]()

        for i in stride(from: 0, to: array.count, by: 2) {
            let key = array[i].keyValueDecoded()
            let value = array[i + 1].keyValueDecoded()
            result[key] = value
        }

        return result
    }
}

extension String {
    func keyValueEncoded() -> String {
        return
            self
            .replacingOccurrences(of: "%", with: "%25")
            .replacingOccurrences(of: ",", with: "%2C")
    }

    func keyValueDecoded() -> String {
        return
            self
            .replacingOccurrences(of: "%2C", with: ",")
            .replacingOccurrences(of: "%25", with: "%")
    }
}
