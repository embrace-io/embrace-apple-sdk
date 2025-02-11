//
//  SpanTestUIComponentViewModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

class SpanTestUIComponentViewModel: UIComponentViewModelBase {
    var spanExporter: TestSpanExporter = .init()
    private var testing = false
    private weak var observingObject: NSObjectProtocol?

    func spanExporterUpdated() {
        switch spanExporter.state {
        case .waiting, .testing:
            self.readyToTest = false
        case .clear, .ready:
            self.readyToTest = true
            //        case .ready:
            //            if testing {
            //                updateTestReport(with: spanExporter.performTest(self.dataModel.payloadTestObject))
            //            } else {
            //                self.dataModel.payloadTestObject.runTestPreparations()
            //            }
            //        }
        }
    }

    override func testButtonPressed() {
        self.spanExporter.clearAll(self.dataModel.payloadTestObject.testRelevantSpanName)

        registerForNotification()

        self.testing = true
        self.readyToTest = false

        self.dataModel.payloadTestObject.runTestPreparations()
    }

    private func registerForNotification() {
        observingObject = NotificationCenter.default.addObserver(forName: .init("TestSpanExporter.SpansUpdated"), object: nil, queue: nil) { [weak self] _ in
            guard let self = self,
            let spans = self.spanExporter.cachedExportedSpans[self.dataModel.payloadTestObject.testRelevantSpanName],
            !spans.isEmpty
            else { return }

            self.updateTestReport(with: self.dataModel.payloadTestObject.test(spans: spans))
            self.testHasFinished()
        }
    }

    private func testHasFinished() {
        guard let observingObject = observingObject else { return }

        NotificationCenter.default.removeObserver(observingObject, name: .init("TestSpanExporter.SpansUpdated"), object: nil)
        self.testing = false
        self.readyToTest = true
    }
}
