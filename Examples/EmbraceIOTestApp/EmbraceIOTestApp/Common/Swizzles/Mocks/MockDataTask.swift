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

    // A task created with `init()` reports `.running` before `resume()`, but the SDK only captures
    // tasks that are still `.suspended`. Track the state like a real task so the mocked Embrace API
    // requests still get network spans.
    private let stateLock = NSLock()
    private var _state: URLSessionTask.State = .suspended
    override var state: URLSessionTask.State { stateLock.withLock { _state } }

    init(originalRequest: URLRequest?, completionData: Data? = nil, completion: URLSessionCompletion!) {
        self._originalRequest = originalRequest
        self.completion = completion
        self.completionData = completionData
    }

    override func resume() {
        let started = stateLock.withLock {
            guard _state == .suspended else { return false }
            _state = .running
            return true
        }
        guard started else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            self.stateLock.withLock { self._state = .completed }
            self.completion(self.completionData, self.fakeHTTPResponse, nil)
        }
    }

    var fakeHTTPResponse: HTTPURLResponse? {
        .init(url: URL(string: "https://embrace.io")!, statusCode: 200, httpVersion: nil, headerFields: nil)
    }

    var completionData: Data?
}
