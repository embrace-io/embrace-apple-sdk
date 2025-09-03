//
//  PerformanceTestSpansViewModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import EmbraceCore
import OpenTelemetryApi

@Observable
class PerformanceTestSpansViewModel: SpanTestUIComponentViewModel {
    private var testObject: PerformanceSpanTest
    var numberOfConcurrentLoops: Double {
        didSet {
            updateTestObject()
        }
    }

    var numberOfCalculationsPerLoop: Double {
        didSet {
            updateTestObject()
        }
    }

    var limitNumberOfSpansPerLoop: Double {
        didSet {
            updateTestObject()
        }
    }
    
    let maxConcurrentLoops: Double = 30
    let maxCalculationsPerLoop: Double = 10000
    let maxNumberOfSpansPerLoop: Double = 3000

    init(dataModel: any TestScreenDataModel) {
        let testObject = PerformanceSpanTest()
        self.testObject = testObject
        numberOfConcurrentLoops = 10
        numberOfCalculationsPerLoop = 5000
        limitNumberOfSpansPerLoop = 100
        super.init(dataModel: dataModel, payloadTestObject: testObject)
    }
    private func updateTestObject() {
        testObject.numberOfLoops = Int(min(max(1, numberOfConcurrentLoops), maxConcurrentLoops))
        testObject.calculationsPerLoop = Int(min(max(1, numberOfCalculationsPerLoop), maxCalculationsPerLoop))
        testObject.maxNumberOfSpans = Int(min(max(1, limitNumberOfSpansPerLoop), maxNumberOfSpansPerLoop))
    }
    override func testButtonPressed() {
        updateTestObject()
        super.testButtonPressed()
    }
}
