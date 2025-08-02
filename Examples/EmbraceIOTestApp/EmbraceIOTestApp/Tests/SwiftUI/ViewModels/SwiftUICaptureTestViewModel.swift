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
    var loadedState: SwiftUITestsLoadedState = .dontInclude {
        didSet {
            testObject.loaded = loadedState
        }
    }
    var presentDummyView: Bool = false

    var attributes: [String: String] {
        testObject.attributes
    }
    var loaded: Bool? { loadedState.boolValue }

    init(dataModel: any TestScreenDataModel, captureType: SwiftUICaptureType) {
        let testObject = SwiftUICaptureTest()
        testObject.captureType = captureType
        self.testObject = testObject
        self.captureType = captureType
        super.init(dataModel: dataModel, payloadTestObject: testObject)
    }

    func addAttribute(key: String, value: String) {
        testObject.attributes[key] = value
    }

    override func testButtonPressed() {
        presentDummyView = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.presentDummyView = false
        }

        super.testButtonPressed()
    }
}
