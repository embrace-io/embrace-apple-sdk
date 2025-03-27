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

    @Published var api: String = "" {
        didSet {
            testObject.api = api
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

    func addBodyProperty(key: String, value: String) {
        testObject.requestBody[key.replacingOccurrences(of: " ", with: "").lowercased()] = value
    }
}
