//
//  PerformanceTestLogsViewModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

@Observable
class PerformanceTestLogsViewModel: SpanTestUIComponentViewModel {
    private var testObject: PerformanceLogTest
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

    var limitNumberOfLogsPerLoop: Double {
        didSet {
            updateTestObject()
        }
    }

    let maxConcurrentLoops: Double = 30
    let maxCalculationsPerLoop: Double = 10000
    let maxNumberOfLogsPerLoop: Double = 3000

    init(dataModel: any TestScreenDataModel) {
        let testObject = PerformanceLogTest()
        self.testObject = testObject
        numberOfConcurrentLoops = 10
        numberOfCalculationsPerLoop = 5000
        limitNumberOfLogsPerLoop = 100
        super.init(dataModel: dataModel, payloadTestObject: testObject)
    }
    private func updateTestObject() {
        testObject.numberOfLoops = Int(min(max(1, numberOfConcurrentLoops), maxConcurrentLoops))
        testObject.calculationsPerLoop = Int(min(max(1, numberOfCalculationsPerLoop), maxCalculationsPerLoop))
        testObject.maxNumberOfLogs = Int(min(max(1, limitNumberOfLogsPerLoop), maxNumberOfLogsPerLoop))
    }
    override func testButtonPressed() {
        updateTestObject()
        super.testButtonPressed()
    }
}
