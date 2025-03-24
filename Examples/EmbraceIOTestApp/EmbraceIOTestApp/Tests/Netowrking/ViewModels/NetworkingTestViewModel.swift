//
//  NetworkingTestViewModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import EmbraceCommonInternal

class NetworkingTestViewModel: SpanTestUIComponentViewModel {
    private var testObject: NetworkingTest = .init()

    @Published var testURL: String = "https://embrace.io" {
        didSet {
            testObject.testURL = testURL
        }
    }

    @Published var requestMethod: URLRequestMethod = .get {
        didSet {
            testObject.requestMethod = requestMethod
        }
    }

    init(dataModel: any TestScreenDataModel) {
        super.init(dataModel: dataModel, payloadTestObject: self.testObject)
    }
}
