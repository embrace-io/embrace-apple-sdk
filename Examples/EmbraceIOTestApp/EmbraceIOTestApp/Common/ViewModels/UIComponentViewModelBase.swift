//
//  UIComponentViewModelBase.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import EmbraceIO

@Observable class UIComponentViewModelBase: NSObject, UIComponentViewModelType {
    private(set) var testReport: TestReport = .init(items: [])
    var readyToTest: Bool = false {
        didSet {
            self.objectWillChange.send()
        }
    }

    var testResult: TestResult {
        switch self.state {
        case .idle(_):
            return .unknown
        case .testing:
            return .testing
        case let .testComplete(result):
            return result
        }
    }

    private(set) var dataModel: any TestScreenDataModel

    var state: TestViewModelState = .idle(false) {
        didSet {
            switch state {
            case .idle(true), .testComplete(_):
                readyToTest = true
            default:
                readyToTest = false
            }
            self.objectWillChange.send()
        }
    }

    init(dataModel: any TestScreenDataModel) {
        self.dataModel = dataModel
        super.init()
        self.checkEmbraceStatus()
    }

    func testStarted() {
        self.state = .testing
    }

    func testFinished(with report: TestReport) {
        self.testReport = report
        self.state = .testComplete(report.result)
    }

    func testButtonPressed() {
        testStarted()
    }

    private func checkEmbraceStatus() {
        guard Embrace.client?.state != .started else {
            self.state = .idle(true)
            return
        }

        NotificationCenter.default.addObserver(forName: .init("TestSpanExporter.EmbraceStarted"), object: nil, queue: nil) { [weak self] _ in
            self?.state = .idle(true)
        }
    }
}
