//
//  String+Extensions.swift
//  EmbraceIOTestApp
//
//

import Foundation

extension String {
    func toData() -> Data? {
        self.data(using: .utf8, allowLossyConversion: false)
    }

    func containsUppercase() -> Bool {
        let regex  = ".*[A-Z]+.*"
        let test = NSPredicate(format:"SELF MATCHES %@", regex)
        return test.evaluate(with: self)
    }
}
