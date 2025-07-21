//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import XCTest

@testable import EmbraceOTelInternal

class EmbraceLoggerProviderTests: XCTestCase {
    private var sut: DefaultEmbraceLoggerProvider!
    private var sharedState: EmbraceLogSharedState!
    private var resultLogger: Logger!
    private var resultLoggerBuilder: LoggerBuilder!

    override func setUpWithError() throws {
        givenSharedState(config: RandomConfig())
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
        let provider = DefaultEmbraceLoggerProvider(sharedState: MockEmbraceLogSharedState())
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
        class ZeroedConfig: EmbraceLoggerConfig {
            var batchLifetimeInSeconds: Int = 0
            var maximumTimeBetweenLogsInSeconds: Int = 0
            var maximumMessageLength: Int = 0
            var maximumAttributes: Int = 0
            var logAmountLimit: Int = 0
        }
        givenSharedState(config: ZeroedConfig())
        givenLoggerBuilderProvider()
        givenLoggerWasCreatedWithProvider()
        whenInvokingProviderUpdate(withConfig: RandomConfig())
        try thenLoggersConfigIsRandomEmbraceLoggerConfig()
    }
}

extension EmbraceLoggerProviderTests {
    fileprivate func givenSharedState(config: any EmbraceLoggerConfig) {
        sharedState = MockEmbraceLogSharedState(config: config)
    }

    fileprivate func givenLoggerBuilderProvider() {
        sut = DefaultEmbraceLoggerProvider(sharedState: sharedState)
    }

    fileprivate func givenLoggerWasCreatedWithProvider() {
        resultLogger = sut.get()
    }

    fileprivate func whenInvokingGet(withInstrumentationScopeName instrumentationScopeName: String) {
        resultLogger = sut.get(instrumentationScopeName: instrumentationScopeName)
    }

    fileprivate func whenInvokingGet() {
        resultLogger = sut.get()
    }

    fileprivate func whenInvokingLoggerBuilder(withInstrumentationScopeName instrumentationScopeName: String = "") {
        resultLoggerBuilder = sut.loggerBuilder(instrumentationScopeName: instrumentationScopeName)
    }

    fileprivate func whenInvokingProviderUpdate(withConfig config: any EmbraceLoggerConfig) {
        sut.update(config)
    }

    fileprivate func thenLoggerIsEmbraceLogger() {
        XCTAssertTrue(resultLogger is EmbraceLogger)
    }

    fileprivate func thenLoggerBuilderIsEmbraceLoggerBuilder() {
        XCTAssertTrue(resultLoggerBuilder is EmbraceLoggerBuilder)
    }

    fileprivate func thenLoggersConfigIsRandomEmbraceLoggerConfig() throws {
        let embraceLogger = try XCTUnwrap(resultLogger as? EmbraceLogger)
        XCTAssertTrue(embraceLogger.sharedState.config is RandomConfig)
    }
}
