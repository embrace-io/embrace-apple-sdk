//
//  StartupStateTestViewModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

@Observable
class StartupStateTestViewModel: SpanTestUIComponentViewModel {
    private var testObject: StartupStateSpanTest

    var coldStartExpected: Bool = false {
        didSet {
            testObject.expectsColdStart = coldStartExpected
        }
    }

    init(dataModel: any TestScreenDataModel) {
        let testObject = StartupStateSpanTest()
        self.testObject = testObject
        super.init(dataModel: dataModel, payloadTestObject: testObject)
    }
}
