import XCTest

@testable import EmbraceIO

final class EmbraceClientTests: XCTestCase {

    func test_init() throws {
        let a = EmbraceClient(appId: "myApp")

        let b = EmbraceClient(appId: "myApp", appGroupIdentifier: "com.appgroup.identifier")

        let c = EmbraceClient(appId: "myApp", appGroupIdentifier: "com.appgroup.identifier", instruments: .default)

    }

}
