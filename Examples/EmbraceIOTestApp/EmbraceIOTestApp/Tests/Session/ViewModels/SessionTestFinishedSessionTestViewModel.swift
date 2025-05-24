//
//  SessionTestFinishedSessionTestViewModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

@Observable
class SessionTestFinishedSessionTestViewModel: SpanTestUIComponentViewModel {
    private var testObject: FinishedSessionTest

    var fakeAppState: Bool = false {
        didSet {
            testObject.fakeAppState = fakeAppState
        }
    }

    init(dataModel: any TestScreenDataModel) {
        let testObject = FinishedSessionTest()
        self.testObject = testObject
        super.init(dataModel: dataModel, payloadTestObject: testObject)
    }
}
