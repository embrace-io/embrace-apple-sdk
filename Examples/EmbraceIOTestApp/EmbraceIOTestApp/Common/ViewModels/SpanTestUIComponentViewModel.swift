//
//  SpanTestUIComponentViewModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

class SpanTestUIComponentViewModel: UIComponentViewModelBase {
    var spanExporter: TestSpanExporter = .init()
    private weak var observingObject: NSObjectProtocol?

    override func testButtonPressed() {
        super.testButtonPressed()
        
        // if test object requirest tests to be run immediately if relevant spans are already present
        guard !payloadTestObject.runImmediatelyIfSpansFound || (spanExporter.cachedExportedSpans[payloadTestObject.testRelevantSpanName]?.count ?? 0) == 0 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.performTest()
            }
            return
        }

        if payloadTestObject.requiresCleanup {
            spanExporter.clearAll(payloadTestObject.testRelevantSpanName)
        }

        registerForNotification()

        payloadTestObject.runTestPreparations()
    }

    private func registerForNotification() {
        observingObject = NotificationCenter.default.addObserver(forName: .init("TestSpanExporter.SpansUpdated"), object: nil, queue: nil) { [weak self] _ in
            self?.performTest()
        }
    }

    private func performTest() {
        guard
            let spans = spanExporter.cachedExportedSpans[payloadTestObject.testRelevantSpanName],
            !spans.isEmpty
        else { return }

        let testReport = payloadTestObject.test(spans: spans)
        testFinished(with: testReport)
    }

    private func testHasFinished() {
        guard let observingObject = observingObject else { return }

        NotificationCenter.default.removeObserver(observingObject, name: .init("TestSpanExporter.SpansUpdated"), object: nil)
    }
}
