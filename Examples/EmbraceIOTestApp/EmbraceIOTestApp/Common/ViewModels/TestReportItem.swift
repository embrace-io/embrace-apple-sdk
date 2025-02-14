//
//  TestReportItem.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct TestReportItem: Identifiable {
    var id: UUID

    /// `target`: the key to test
    /// `expected`: the expected value under said key
    /// `recorded`: the actual value found in the payload. If testing for existence, you can just add a descriptive text like "exists".
    /// `result`: the outcome of the test
    init(target: String, expected: String, recorded: String, result: TestResult) {
        id = UUID()
        self.target = target
        self.expected = expected
        self.recorded = recorded
        self.result = result
    }

    let target: String
    let expected: String
    let recorded: String
    let result: TestResult

    var passed: Bool {
        result == .success
    }
}
