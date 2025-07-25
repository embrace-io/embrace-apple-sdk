//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceOTelInternal
@testable import EmbraceStorageInternal

class DummyEmbraceResourceProvider: EmbraceResourceProvider {
    func getResource() -> Resource { Resource() }
}

class EmbraceLoggerSharedStateTests: XCTestCase {
    private var sut: DefaultEmbraceLogSharedState!
    let sdkStateProvider = MockEmbraceSDKStateProvider()

    func test_default_hasDefaultEmbraceLoggerConfig() throws {
        try whenInvokingDefaultEmbraceLoggerSharedState()
        thenConfig(is: DefaultEmbraceLoggerConfig())
    }

    func test_default_hasNoProcessors() throws {
        try whenInvokingDefaultEmbraceLoggerSharedState()
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

extension EmbraceLoggerSharedStateTests {
    fileprivate func givenEmbraceLoggerSharedState(config: any EmbraceLoggerConfig) {
        sut = .init(config: config, processors: [], resourceProvider: DummyEmbraceResourceProvider())
    }

    fileprivate func whenInvokingUpdate(withConfig config: any EmbraceLoggerConfig) {
        sut.update(config)
    }

    fileprivate func whenInvokingDefaultEmbraceLoggerSharedState() throws {
        sut = try .create(
            storage: EmbraceStorage.createInMemoryDb(),
            batcher: SpyLogBatcher(),
            sdkStateProvider: sdkStateProvider
        )
    }

    fileprivate func thenConfig(is config: any EmbraceLoggerConfig) {
        XCTAssertEqual(sut.config.logAmountLimit, config.logAmountLimit)
    }

    fileprivate func thenProcessorsArrayHasDefaultProcessors() {
        XCTAssertFalse(sut.processors.isEmpty)
    }
}
