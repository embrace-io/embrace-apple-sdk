//
//  TestReport.swift
//  EmbraceIOTestApp
//
//

struct TestReport {
    var result: TestResult = .unknown

    var items: [TestReportItem] = []

    var passed: Bool {
        result == .success
    }
}
