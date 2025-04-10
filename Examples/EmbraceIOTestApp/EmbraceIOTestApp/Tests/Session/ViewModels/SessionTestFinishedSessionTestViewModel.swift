//
//  SessionTestFinishedSessionTestViewModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

class SessionTestFinishedSessionTestViewModel: SpanTestUIComponentViewModel {
    private var testObject: FinishedSessionTest = .init()

    @Published var fakeAppState: Bool = false {
        didSet {
            testObject.fakeAppState = fakeAppState
        }
    }

    init(dataModel: any TestScreenDataModel) {
        super.init(dataModel: dataModel, payloadTestObject: self.testObject)
    }
}
