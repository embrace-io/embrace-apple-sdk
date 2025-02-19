//
//  LogTestUIComponentViewModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

class LogTestUIComponentViewModel: UIComponentViewModelBase {
    var logExporter: TestLogRecordExporter = .init()

    private weak var observingObject: NSObjectProtocol?

    override func testButtonPressed() {
        super.testButtonPressed()

        if payloadTestObject.requiresCleanup {
            logExporter.clearAll(payloadTestObject.testRelevantSpanName)
        }

        registerForNotification()

        payloadTestObject.runTestPreparations()
    }

    private func registerForNotification() {
        observingObject = NotificationCenter.default.addObserver(forName: .init("TestLogRecordExporter.LogsUpdated"), object: nil, queue: nil) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.performTest()
            }
        }
    }

    private func performTest() {
        let testReport = payloadTestObject.test(logs: logExporter.cachedExportedLogs)
        testFinished(with: testReport)
    }

    private func testHasFinished() {
        guard let observingObject = observingObject else { return }

        NotificationCenter.default.removeObserver(observingObject, name: .init("TestLogRecordExporter.LogsUpdated"), object: nil)
    }
}
