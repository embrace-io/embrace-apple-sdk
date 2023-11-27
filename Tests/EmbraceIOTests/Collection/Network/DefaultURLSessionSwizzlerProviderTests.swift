//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//


import XCTest

@testable import EmbraceIO

class DefaultURLSessionSwizzlerProviderTests: XCTestCase {
    private var sut: DefaultURLSessionSwizzlerProvider!

    override func setUp() {
        sut = .init()
    }

    func test_onInit_shouldProvideAllTheCorrectSwizzlerClasses() {
        let expectedTypes: [any URLSessionSwizzler.Type] = [
            DataTaskWithURLSwizzler.self,
            DataTaskWithURLRequestSwizzler.self,
            DataTaskWithURLAndCompletionSwizzler.self,
            DataTaskWithURLRequestAndCompletionSwizzler.self,
            UploadTaskWithRequestFromDataSwizzler.self,
            UploadTaskWithRequestFromDataWithCompletionSwizzler.self,
            UploadTaskWithRequestFromFileSwizzler.self,
            UploadTaskWithRequestFromFileWithCompletionSwizzler.self,
            DownloadTaskWithURLRequestSwizzler.self,
            DownloadTaskWithURLRequestWithCompletionSwizzler.self,
            UploadTaskWithStreamedRequestSwizzler.self,
            URLSessionInitWithDelegateSwizzler.self
        ]
        let swizzlers = sut.getAll(usingHandler: MockURLSessionTaskHandler())
        XCTAssertGreaterThanOrEqual(swizzlers.count, expectedTypes.count)
        for swizzler in swizzlers {
            XCTAssertTrue(expectedTypes.contains(where: { $0 == type(of: swizzler) }))
        }
    }
}
