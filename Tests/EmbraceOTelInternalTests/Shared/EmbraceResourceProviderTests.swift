//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetrySdk
import XCTest

@testable import EmbraceOTelInternal

struct MockResourceProvider: EmbraceResourceProvider {
    let resource: Resource

    func getResource() -> Resource {
        return resource
    }
}

final class EmbraceResourceProviderTests: XCTestCase {

    func test_getResource_returnsResourceWithDefaultAttributes() throws {
        let provider = MockResourceProvider(resource: .init())
        let resource = provider.getResource()

        XCTAssertFalse(resource.attributes.isEmpty)

        XCTAssertNotNil(resource.attributes["service.name"])
        XCTAssertEqual(resource.attributes["telemetry.sdk.language"], .string("swift"))
    }

    func test_getResource_allowsOverrideOfDefaultResources() throws {
        let provider = MockResourceProvider(
            resource: Resource(attributes: [
                "service.name": .string("example"),
                "telemetry.sdk.language": .string("bacon"),
            ]))
        let resource = provider.getResource()

        XCTAssertFalse(resource.attributes.isEmpty)
        XCTAssertEqual(resource.attributes["service.name"], .string("example"))
        XCTAssertEqual(resource.attributes["telemetry.sdk.language"], .string("bacon"))
    }

    func test_getResource_includesCustomResourceAttributes() throws {
        let provider = MockResourceProvider(
            resource: Resource(attributes: [
                "my.name": .string("bob"),
                "my.age": .int(42),
                "service.name": .string("example"),
            ]))
        let resource = provider.getResource()

        XCTAssertEqual(resource.attributes.count, 3)
        XCTAssertEqual(resource.attributes["my.name"], .string("bob"))
        XCTAssertEqual(resource.attributes["my.age"], .int(42))
        XCTAssertEqual(resource.attributes["service.name"], .string("example"))
    }
}
