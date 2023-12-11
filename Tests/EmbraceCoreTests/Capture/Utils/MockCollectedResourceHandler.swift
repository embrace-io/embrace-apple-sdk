//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

@testable import EmbraceCore

final class MockCollectedResourceHandler: CaptureServiceResourceHandlerType {
    func addResource(key: String, value: String) throws {
        addedStrings[key] = value
    }

    func addResource(key: String, value: Int) throws {
        addedInts[key] = value
    }

    func addResource(key: String, value: Double) throws {
        addedDoubles[key] = value
    }

    var addedStrings: [String: String] = [:]
    var addedInts: [String: Int] = [:]
    var addedDoubles: [String: Double] = [:]
}
