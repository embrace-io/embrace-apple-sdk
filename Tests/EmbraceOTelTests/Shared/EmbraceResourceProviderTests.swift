//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceOTel

struct MockResourceProvider: EmbraceResourceProvider {
    let resources: [EmbraceResource]

    func getResources() -> [EmbraceResource] {
        return resources
    }
}

final class EmbraceResourceProviderTests: XCTestCase {

    func test_getResource_returnsResourceWithDefaultAttributes() throws {
        let provider = MockResourceProvider(resources: [])
        let resource = provider.getResource()

        XCTAssertFalse(resource.attributes.isEmpty)

        XCTAssertNotNil(resource.attributes["service.name"])
        XCTAssertEqual(resource.attributes["telemetry.sdk.language"], .string("swift"))
    }

    func test_getResource_allowsOverrideOfDefaultResources() throws {
        let provider = MockResourceProvider(resources: [
            DefaultEmbraceResource(key: "service.name", value: .string("example")),
            DefaultEmbraceResource(key: "telemetry.sdk.language", value: .string("bacon"))
        ])
        let resource = provider.getResource()

        XCTAssertFalse(resource.attributes.isEmpty)
        XCTAssertEqual(resource.attributes["service.name"], .string("example"))
        XCTAssertEqual(resource.attributes["telemetry.sdk.language"], .string("bacon"))
    }

    func test_getResource_includesCustomResourceAttributes() throws {
        let provider = MockResourceProvider(resources: [
            DefaultEmbraceResource(key: "my.name", value: .string("bob")),
            DefaultEmbraceResource(key: "my.age", value: .int(42)),
            DefaultEmbraceResource(key: "service.name", value: .string("example"))
        ])
        let resource = provider.getResource()

        XCTAssertEqual(resource.attributes.count, 4)
        XCTAssertEqual(resource.attributes["my.name"], .string("bob"))
        XCTAssertEqual(resource.attributes["my.age"], .int(42))
        XCTAssertEqual(resource.attributes["service.name"], .string("example"))
        XCTAssertEqual(resource.attributes["telemetry.sdk.language"], .string("swift"))
    }

}
