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
}
