//
//  TestReport.swift
//  EmbraceIOTestApp
//
//

struct TestReport {
    private(set) var result: TestResult = .unknown
    let items: [TestReportItem]

    init(items: [TestReportItem]) {
        self.items = items
        self.result = items.contains(where: { $0.result == .fail }) ? .fail : .success
    }

    var passed: Bool {
        result == .success
    }
}
