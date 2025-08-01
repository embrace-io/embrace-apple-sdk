//
//  SwiftUICaptureTestViewModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

@Observable
class SwiftUICaptureTestViewModel: SpanTestUIComponentViewModel {
    private var testObject: SwiftUICaptureTest
    var captureType: SwiftUICaptureType = .manual
    var presentDummyViewManual: Bool = false
    var presentDummyViewMacro: Bool = false
    var presentDummyViewEmbraceView: Bool = false

    init(dataModel: any TestScreenDataModel, captureType: SwiftUICaptureType) {
        let testObject = SwiftUICaptureTest()
        testObject.captureType = captureType
        self.testObject = SwiftUICaptureTest()
        self.captureType = captureType
        super.init(dataModel: dataModel, payloadTestObject: testObject)
    }

    override func testButtonPressed() {
        switch captureType {
        case .manual:
            presentDummyViewManual = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.presentDummyViewManual = false
            }
        case .macro:
            presentDummyViewMacro = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.presentDummyViewMacro = false
            }
        case .embraceView:
            presentDummyViewEmbraceView = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.presentDummyViewEmbraceView = false
            }
        }

        super.testButtonPressed()
    }
}
