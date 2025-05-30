//
//  MockDataTask.swift
//  EmbraceIOTestApp
//
//

import Foundation

class MockDataTask: URLSessionDataTask, @unchecked Sendable {
    typealias URLSessionCompletion = (Data?, URLResponse?, Error?) -> Void

    var completion: URLSessionCompletion!
    var _originalRequest: URLRequest?
    override var originalRequest: URLRequest? { _originalRequest }

    init(originalRequest: URLRequest?, completionData: Data? = nil, completion: URLSessionCompletion!) {
        self._originalRequest = originalRequest
        self.completion = completion
        self.completionData = completionData
    }

    override func resume() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            self.completion(self.completionData, self.fakeHTTPResponse, nil)
        }
    }

    var fakeHTTPResponse: HTTPURLResponse? {
        .init(url: URL(string: "https://embrace.io")!, statusCode: 200, httpVersion: nil, headerFields: nil)
    }

    var completionData: Data?
}
