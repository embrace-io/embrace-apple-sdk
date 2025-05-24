//
//  NetworkingTestViewModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import EmbraceCommonInternal

@Observable
class NetworkingTestViewModel: SpanTestUIComponentViewModel {
    private var testObject: NetworkingTest

    var testURL: String = "https://embrace.io" {
        didSet {
            testObject.testURL = testURL
        }
    }

    var api: String = "" {
        didSet {
            testObject.api = api
        }
    }

    var requestMethod: URLRequestMethod = .get {
        didSet {
            testObject.requestMethod = requestMethod
        }
    }

    init(dataModel: any TestScreenDataModel) {
        let testObject = NetworkingTest()
        self.testObject = testObject
        super.init(dataModel: dataModel, payloadTestObject: testObject)
    }

    func addBodyProperty(key: String, value: String) {
        testObject.requestBody[key.replacingOccurrences(of: " ", with: "").lowercased()] = value
    }
}
