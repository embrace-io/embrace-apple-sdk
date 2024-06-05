//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import EmbraceOTel
import EmbraceStorage
import TestSupport
@testable import EmbraceCore

class ConcreteResourceExporterTests: XCTestCase {
    private var sut: ConcreteResourceExporter!
    private var exporter: SpyEmbraceResourceProvider!
    private var blockedKeys: [String]!
    private var result: [EmbraceResource]?

    override func setUp() {
        givenBlockedKeys()
        givenExporter()
    }

    func test_getResources_willAlwaysGetResourcesFromInternalExporter() {
        givenConcreteResourceExporter()
        whenInvokingGetResources()
        thenInternalExporterShouldBeCalled()
    }

    func testHavingBlockedKeys_getResources_shouldRemoveBlockedKeys() throws {
        let resources: [EmbraceResource] = [
            ConcreteEmbraceResource(key: "blocked", value: .string("some_value")),
            ConcreteEmbraceResource(key: "non_blocked", value: .string("some_other_value"))
        ]
        givenExporter(withResources: resources)
        givenBlockedKeys(["blocked", "another_blocked_key"])
        givenConcreteResourceExporter()

        whenInvokingGetResources()

        try thenResourcesShouldntContain(key: "blocked")
        try thenResourcesShouldContain(key: "non_blocked")
    }

    func testHavingEmbResources_getResources_shouldRemovePrefixOnlyOnThoseWhoHaveEmbPrefix() throws {
        let resources: [EmbraceResource] = [
            ConcreteEmbraceResource(key: "emb.some.property", value: .string(.random())),
            ConcreteEmbraceResource(key: "non.embrace.property", value: .string(.random())),
            ConcreteEmbraceResource(key: "with.emb.in.middle", value: .string(.random())),
            ConcreteEmbraceResource(key: "emb.another.property", value: .string(.random()))
        ]

        givenExporter(withResources: resources)
        givenConcreteResourceExporter()

        whenInvokingGetResources()

        try thenResourcesShouldntContain(keys: [
            "emb.some.property",
            "emb.another.property"
        ])
        try thenResourcesShouldContain(keys: [
            "some.property",
            "non.embrace.property",
            "with.emb.in.middle",
            "another.property"
        ])
    }

    func testHavingResourcesAndBlockedKeys_getResource_shouldFilterFirst() throws {
        let resources: [EmbraceResource] = [
            ConcreteEmbraceResource(key: "emb.blocked", value: .string(.random())),
            ConcreteEmbraceResource(key: "another_blocked", value: .string(.random())),
            ConcreteEmbraceResource(key: "a_resource", value: .string(.random())),
            ConcreteEmbraceResource(key: "emb.a_second_resource", value: .string(.random()))
        ]
        givenExporter(withResources: resources)
        givenBlockedKeys(["blocked", "another_blocked"])
        givenConcreteResourceExporter()

        whenInvokingGetResources()

        try thenResourcesShouldContain(keys: ["blocked", "a_resource", "a_second_resource"])
        try thenResourcesShouldntContain(keys: ["another_blocked"])
    }

    // MARK: - Factory Method

    // This test is not that tidy, but ensures that the internalExporter always have the ResourceStorageExporter
    func test_create_setsInternalExporterAsResourceStorageExporter() throws {
        let storage = try EmbraceStorage(options: .init(named: ""), logger: MockLogger())
        let createdExporter = ConcreteResourceExporter.create(storage: storage)
        let mirror = Mirror(reflecting: createdExporter)
        let internalExporter = try mirror.children.first(where: {
            try XCTUnwrap($0.label).contains("internalExporter")
        })

        let reflectedInternalExporterValue = String(describing: try XCTUnwrap(internalExporter?.value))
        let resourceStorageType = String(describing: ResourceStorageExporter.self)
        XCTAssertTrue(reflectedInternalExporterValue.contains(resourceStorageType))
    }
}

private extension ConcreteResourceExporterTests {
    func givenBlockedKeys(_ keys: [String] = []) {
        blockedKeys = keys
    }

    func givenExporter(withResources resources: [EmbraceResource] = []) {
        exporter = SpyEmbraceResourceProvider()
        exporter.stubbedGetResources = resources
    }

    func givenConcreteResourceExporter() {
        sut = .init(exporter, blockedKeys: blockedKeys)
    }

    func whenInvokingGetResources() {
        result = sut.getResources()
    }

    func thenInternalExporterShouldBeCalled() {
        XCTAssertTrue(exporter.didCallGetResources)
    }

    func thenResourcesShouldntContain(keys: [String]) throws {
        try keys.forEach { try thenResourcesShouldntContain(key: $0) }
    }

    func thenResourcesShouldntContain(key: String) throws {
        let unwrappedResult = try XCTUnwrap(result)
        XCTAssertFalse(unwrappedResult.contains(where: { $0.key == key }))
    }

    func thenResourcesShouldContain(keys: [String]) throws {
        try keys.forEach { try thenResourcesShouldContain(key: $0) }
    }

    func thenResourcesShouldContain(key: String) throws {
        let unwrappedResult = try XCTUnwrap(result)
        XCTAssertTrue(unwrappedResult.contains(where: { $0.key == key }))
    }
}

class SpyEmbraceResourceProvider: EmbraceResourceProvider {
    var stubbedGetResources: [EmbraceResource] = []
    var didCallGetResources: Bool = false
    func getResources() -> [EmbraceResource] {
        didCallGetResources = true
        return stubbedGetResources
    }
}
