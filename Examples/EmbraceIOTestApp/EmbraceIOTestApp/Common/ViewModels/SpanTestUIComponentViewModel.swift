//
//  SpanTestUIComponentViewModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

class SpanTestUIComponentViewModel: UIComponentViewModelBase {
    var spanExporter: TestSpanExporter = .init()
    private weak var observingObject: NSObjectProtocol?

    override func testButtonPressed(_ clearBeforeBegin: Bool = true) {
        if clearBeforeBegin {
            self.spanExporter.clearAll(self.dataModel.payloadTestObject.testRelevantSpanName)
        }

        registerForNotification()

        self.dataModel.payloadTestObject.runTestPreparations()

        testStarted()
    }

    private func registerForNotification() {
        observingObject = NotificationCenter.default.addObserver(forName: .init("TestSpanExporter.SpansUpdated"), object: nil, queue: nil) { [weak self] _ in
            guard let self = self,
            let spans = self.spanExporter.cachedExportedSpans[self.dataModel.payloadTestObject.testRelevantSpanName],
            !spans.isEmpty
            else { return }

            let testReport = self.dataModel.payloadTestObject.test(spans: spans)
            self.testFinished(with: testReport)
        }
    }

    private func testHasFinished() {
        guard let observingObject = observingObject else { return }

        NotificationCenter.default.removeObserver(observingObject, name: .init("TestSpanExporter.SpansUpdated"), object: nil)
    }
}
