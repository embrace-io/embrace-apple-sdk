//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import XCTest

import OpenTelemetryApi
import OpenTelemetrySdk

@testable import EmbraceOTelInternal

class EmbraceLogSharedStateTests: XCTestCase {
    private var sut: EmbraceLogSharedState!
    private var resourceProvider: SpyEmbraceResourceProvider!
    private var result: Resource!

    func testEveryImplementation_onGetResource_mergesAllAttributesInAResource() {
        givenResourceProvider(
            withResource: Resource(attributes: [
                "hello": .string("world"),
                "IsTrue": .bool(true),
                "number": .int(123)
            ])
        )
        givenAnyImplementationOfEmbraceLogSharedState()
        whenInvokingGetResource()
        thenResultingResource(
            hasAttributes: [
                "hello": .string("world"),
                "IsTrue": .bool(true),
                "number": .int(123)
            ]
        )
    }
}

private extension EmbraceLogSharedStateTests {
    func givenResourceProvider(withResource resource: Resource) {
        resourceProvider = .init()
        resourceProvider.stubbedResource = resource
    }

    func givenAnyImplementationOfEmbraceLogSharedState() {
        sut = DummyEmbraceLogShared(resourceProvider: resourceProvider)
    }

    func whenInvokingGetResource() {
        result = sut.getResource()
    }

    func thenResultingResource(hasAttributes attributes: [String: AttributeValue]) {
        attributes.forEach { attribute in
            let doContainAttribute = result.attributes.contains { resourceAttribute in
                attribute == resourceAttribute
            }
            XCTAssertTrue(doContainAttribute)
        }
    }
}
