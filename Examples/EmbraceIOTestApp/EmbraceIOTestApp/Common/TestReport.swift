//
//  TestReport.swift
//  EmbraceIOTestApp
//
//

struct TestReport {
    var result: TestResult

    let testItems: [TestItem]

    var passed: Bool {
        result == .success
    }
}
