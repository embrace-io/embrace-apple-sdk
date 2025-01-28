//
//  TestItem.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct TestItem: Identifiable {
    var id: UUID

    enum Result {
        case pass
        case fail

        init(_ testPassed: Bool) {
            if testPassed {
                self = .pass
            } else {
                self = .fail
            }
        }
    }

    /// `target`: the key to test
    /// `expected`: the expected value under said key
    /// `recorded`: the actual value found in the payload. If testing for existence, you can just add a descriptive text like "exists".
    /// `result`: the outcome of the test
    init(target: String, expected: String, recorded: String, result: Result) {
        id = UUID()
        self.target = target
        self.expected = expected
        self.recorded = recorded
        self.result = result
    }

    let target: String
    let expected: String
    let recorded: String
    let result: Result

    var passed: Bool {
        result == .pass
    }
}
