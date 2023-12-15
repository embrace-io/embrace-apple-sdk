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

private extension URLSessionTaskExtensionTests {
    func givenRandomURLSessionTask() {
        sut = URLSession.shared.dataTask(with: URLRequest(url: URL(string: "https://embrace.io")!))
    }

    func givenRandomDataToSet() {
        dataToSet = UUID().uuidString.data(using: .utf8)!
    }

    func whenInvokingSetEmbraceData() {
        sut.embraceData = dataToSet
    }

    func thenEmbraceDataIsNil() {
        XCTAssertNil(sut.embraceData)
    }

    func thenEmbraceDataShouldHaveThatData() {
        XCTAssertEqual(dataToSet, sut.embraceData)
    }
}
