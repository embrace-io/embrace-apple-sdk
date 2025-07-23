//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore

class URLSessionTaskExtensionTests: XCTestCase {
    private var sut: URLSessionTask!
    private var dataToSet: Data!

    func test_onCreation_embraceDataIsNil() {
        givenRandomURLSessionTask()
        thenEmbraceDataIsNil()
    }

    func test_onSetEmbraceData_dataShouldBeRetained() {
        givenRandomURLSessionTask()
        givenRandomDataToSet()
        whenInvokingSetEmbraceData()
        thenEmbraceDataShouldHaveThatData()
    }
}

extension URLSessionTaskExtensionTests {
    fileprivate func givenRandomURLSessionTask() {
        sut = URLSession.shared.dataTask(with: URLRequest(url: URL(string: "https://embrace.io")!))
    }

    fileprivate func givenRandomDataToSet() {
        dataToSet = UUID().uuidString.data(using: .utf8)!
    }

    fileprivate func whenInvokingSetEmbraceData() {
        sut.embraceData = dataToSet
    }

    fileprivate func thenEmbraceDataIsNil() {
        XCTAssertNil(sut.embraceData)
    }

    fileprivate func thenEmbraceDataShouldHaveThatData() {
        XCTAssertEqual(dataToSet, sut.embraceData)
    }
}
