//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import OpenTelemetryApi

@testable import EmbraceOTel

class EmbraceLoggerProviderTests: XCTestCase {
    private var sut: DefaultEmbraceLoggerProvider!
    private var sharedState: EmbraceLoggerSharedState!
    private var resultLogger: Logger!
    private var resultLoggerBuilder: LoggerBuilder!

    override func setUpWithError() throws {
        givenSharedState(config: DefaultEmbraceLoggerConfig())
    }

    func test_getWithInstrumentation_alwaysReturnsEmbraceLogger() {
        givenLoggerBuilderProvider()
        whenInvokingGet(withInstrumentationScopeName: UUID().uuidString)
        thenLoggerIsEmbraceLogger()
    }

    func test_get_alwaysReturnsEmbraceLogger() {
        givenLoggerBuilderProvider()
        whenInvokingGet()
        thenLoggerIsEmbraceLogger()
    }

    func test_get_alwaysReturnsSameInstanceOfEmbraceLogger() throws {
        let provider = DefaultEmbraceLoggerProvider()
        let logger1 = provider.get()
        let logger2 = provider.get()
        let embraceLogger1 = try XCTUnwrap(logger1 as? EmbraceLogger)
        let embraceLogger2 = try XCTUnwrap(logger2 as? EmbraceLogger)
        XCTAssertTrue(embraceLogger1 === embraceLogger2)
    }

    func test_loggerBuilderWithInstrumentationScope_alwaysReturnsEmbraceLoggerBuilder() {
        givenLoggerBuilderProvider()
        whenInvokingLoggerBuilder(withInstrumentationScopeName: UUID().uuidString)
        thenLoggerBuilderIsEmbraceLoggerBuilder()
    }

    func test_update_changesTheConfigOfSharedStateThroughAllChildren() throws {
        class DummyConfig: EmbraceLoggerConfig {
            var maximumInactivityTimeInSeconds: Int = .random(in: 0...1000)
            var maximumTimeBetweenLogsInSeconds: Int = .random(in: 0...1000)
            var maximumMessageLength: Int = .random(in: 0...1000)
            var maximumAttributes: Int = .random(in: 0...1000)
            var logAmountLimit: Int = .random(in: 0...1000)
        }
        givenSharedState(config: DummyConfig())
        givenLoggerBuilderProvider()
        givenLoggerWasCreatedWithProvider()
        whenInvokingProviderUpdate(withConfig: DefaultEmbraceLoggerConfig())
        thenProviderConfigIsDefaultEmbraceLoggerConfig()
        try thenLoggersConfigIsDefaultEmbraceLoggerConfig()
    }
}

private extension EmbraceLoggerProviderTests {
    func givenSharedState(config: any EmbraceLoggerConfig) {
        sharedState = EmbraceLoggerSharedState(resource: .init(),
                                               config: config,
                                               processors: [])
    }

    func givenLoggerBuilderProvider() {
        sut = DefaultEmbraceLoggerProvider(sharedState: sharedState)
    }

    func givenLoggerWasCreatedWithProvider() {
        resultLogger = sut.get()
    }

    func whenInvokingGet(withInstrumentationScopeName instrumentationScopeName: String) {
        resultLogger = sut.get(instrumentationScopeName: instrumentationScopeName)
    }

    func whenInvokingGet() {
        resultLogger = sut.get()
    }

    func whenInvokingLoggerBuilder(withInstrumentationScopeName instrumentationScopeName: String = "") {
        resultLoggerBuilder = sut.loggerBuilder(instrumentationScopeName: instrumentationScopeName)
    }

    func whenInvokingProviderUpdate(withConfig config: any EmbraceLoggerConfig) {
        sut.update(config)
    }

    func thenLoggerIsEmbraceLogger() {
        XCTAssertTrue(resultLogger is EmbraceLogger)
    }

    func thenLoggerBuilderIsEmbraceLoggerBuilder() {
        XCTAssertTrue(resultLoggerBuilder is EmbraceLoggerBuilder)
    }

    func thenProviderConfigIsDefaultEmbraceLoggerConfig() {
        XCTAssertTrue(sut.sharedState.config is DefaultEmbraceLoggerConfig)
    }

    func thenLoggersConfigIsDefaultEmbraceLoggerConfig() throws {
        let embraceLogger = try XCTUnwrap(resultLogger as? EmbraceLogger)
        XCTAssertTrue(embraceLogger.sharedState.config is DefaultEmbraceLoggerConfig)

    }
}
