//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore
@testable import EmbraceOTel

class DummyEmbraceResourceProvider: EmbraceResourceProvider {
    func getResources() -> [EmbraceResource] { [] }
}

class EmbraceLoggerSharedStateTests: XCTestCase {
    private var sut: DefaultEmbraceLogSharedState!

    func test_default_hasDefaultEmbraceLoggerConfig() {
        whenInvokingDefaultEmbraceLoggerSharedState()
        thenConfig(is: DefaultEmbraceLoggerConfig())
    }

    func test_default_hasNoProcessors() {
        whenInvokingDefaultEmbraceLoggerSharedState()
        thenProcessorsArrayHasDefaultProcessors()
    }

    func test_updateConfig_thenOriginalConfigShouldBeUpdated() {
        class ZeroedConfig: EmbraceLoggerConfig {
            var batchLifetimeInSeconds: Int = 0
            var maximumTimeBetweenLogsInSeconds: Int = 0
            var maximumMessageLength: Int = 0
            var maximumAttributes: Int = 0
            var logAmountLimit: Int = 0
        }
        givenEmbraceLoggerSharedState(config: DefaultEmbraceLoggerConfig())
        whenInvokingUpdate(withConfig: ZeroedConfig())
        thenConfig(is: ZeroedConfig())
    }
}

private extension EmbraceLoggerSharedStateTests {
    func givenEmbraceLoggerSharedState(config: any EmbraceLoggerConfig) {
        sut = .init(config: config, processors: [], resourceProvider: DummyEmbraceResourceProvider())
    }

    func whenInvokingUpdate(withConfig config: any EmbraceLoggerConfig) {
        sut.update(config)
    }

    func whenInvokingDefaultEmbraceLoggerSharedState() {
        sut = .create()
    }

    func thenConfig(is config: any EmbraceLoggerConfig) {
        XCTAssertEqual(sut.config.logAmountLimit, config.logAmountLimit)
    }

    func thenProcessorsArrayHasDefaultProcessors() {
        XCTAssertFalse(sut.processors.isEmpty)
    }
}
