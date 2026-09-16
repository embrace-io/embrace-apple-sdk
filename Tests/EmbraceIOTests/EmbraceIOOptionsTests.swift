//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceConfiguration
import EmbraceSemantics
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceIO

class EmbraceIOOptionsTests: XCTestCase {

    func test_withAppId_derivesEndpointsFromAppId_andNilsRuntimeConfiguration() {
        let options = EmbraceIO.Options.withAppId("myApp")

        XCTAssertEqual(options.appId, "myApp")

        // endpoints default to the Embrace endpoints derived from the appId
        let expected = EmbraceEndpoints(appId: "myApp")
        XCTAssertEqual(options.endpoints?.baseURL, expected.baseURL)
        XCTAssertEqual(options.endpoints?.configBaseURL, expected.configBaseURL)

        // the appId mode never carries a local runtime configuration
        XCTAssertNil(options.runtimeConfiguration)
    }

    func test_withAppId_honorsExplicitEndpoints() {
        let custom = EmbraceEndpoints(baseURL: "base", configBaseURL: "config")
        let options = EmbraceIO.Options.withAppId("myApp", endpoints: custom)

        XCTAssertEqual(options.endpoints?.baseURL, "base")
        XCTAssertEqual(options.endpoints?.configBaseURL, "config")
    }

    func test_withLocalConfiguration_keepsConfig_andHasNilAppIdAndEndpoints() throws {
        let config = MockEmbraceConfigurable()
        let options = EmbraceIO.Options.withLocalConfiguration(config, otel: EmbraceIO.OTelOptions())

        // local-config mode has no appId, so no derived endpoints either
        XCTAssertNil(options.appId)
        XCTAssertNil(options.endpoints)

        // and the provided configuration is retained
        let stored = try XCTUnwrap(options.runtimeConfiguration as? MockEmbraceConfigurable)
        XCTAssertTrue(stored === config)
    }

    // MARK: OTelOptions — signal consumers

    func test_otelOptions_withNoProcessorsOrExporters_hasNoSignalConsumers() {
        XCTAssertFalse(EmbraceIO.OTelOptions().hasSignalConsumers)
    }

    func test_otelOptions_withOnlyAResource_hasNoSignalConsumers() {
        // a resource customizes the data the SDK generates, it doesn't consume signals
        let options = EmbraceIO.OTelOptions(resource: Resource(attributes: ["key": .string("value")]))

        XCTAssertFalse(options.hasSignalConsumers)
        XCTAssertNotNil(options.resource)
    }

    func test_otelOptions_withASpanExporter_hasSignalConsumers() {
        let options = EmbraceIO.OTelOptions(spanExporters: [InMemorySpanExporter()])

        XCTAssertTrue(options.hasSignalConsumers)
    }

    func test_otelOptions_withASpanProcessor_hasSignalConsumers() {
        let options = EmbraceIO.OTelOptions(spanProcessors: [MockSpanProcessor()])

        XCTAssertTrue(options.hasSignalConsumers)
    }

    func test_otelOptions_withALogExporter_hasSignalConsumers() {
        let options = EmbraceIO.OTelOptions(logExporters: [InMemoryLogRecordExporter()])

        XCTAssertTrue(options.hasSignalConsumers)
    }

    // MARK: OTel bridge creation

    func test_makeOTelBridge_withNoOTelOptions_returnsNil() {
        XCTAssertNil(EmbraceIO.makeOTelBridge(for: nil, resource: Resource()))
    }

    func test_makeOTelBridge_withEmptyOTelOptions_returnsNil() {
        // nothing would consume the signals, so the OTel SDK is never initialized
        let options = EmbraceIO.OTelOptions()

        XCTAssertNil(EmbraceIO.makeOTelBridge(for: options, resource: Resource()))
    }

    func test_makeOTelBridge_withOnlyAResource_returnsNil() {
        let options = EmbraceIO.OTelOptions(resource: Resource(attributes: ["key": .string("value")]))

        XCTAssertNil(EmbraceIO.makeOTelBridge(for: options, resource: Resource()))
    }

    func test_makeOTelBridge_withASpanExporter_returnsABridge() {
        let options = EmbraceIO.OTelOptions(spanExporters: [InMemorySpanExporter()])

        XCTAssertNotNil(EmbraceIO.makeOTelBridge(for: options, resource: Resource()))
    }

    func test_makeOTelBridge_withALogExporter_returnsABridge() {
        let options = EmbraceIO.OTelOptions(logExporters: [InMemoryLogRecordExporter()])

        XCTAssertNotNil(EmbraceIO.makeOTelBridge(for: options, resource: Resource()))
    }

    func test_makeOTelBridge_withASpanProcessor_returnsABridge() {
        let options = EmbraceIO.OTelOptions(spanProcessors: [MockSpanProcessor()])

        XCTAssertNotNil(EmbraceIO.makeOTelBridge(for: options, resource: Resource()))
    }
}
