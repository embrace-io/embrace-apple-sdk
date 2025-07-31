//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import TestSupport
import XCTest

@testable import EmbraceCrashlyticsSupport

class CrashlyticsWrapperTests: XCTestCase {

    let options = CrashlyticsWrapper.Options(
        className: "MockCrashlytics",
        singletonSelector: NSSelectorFromString("sharedInstance"),
        setValueSelector: NSSelectorFromString("setCustomValue:forKey:"),
        maxRetryCount: 5,
        retryDelay: 1.0
    )

    override func tearDownWithError() throws {
        MockCrashlytics.instance = nil
    }

    func test_findSingleton() throws {
        // given a mock crashlytics instance
        let mock = MockCrashlytics()
        MockCrashlytics.instance = mock

        // when initializing a crashlytics wrapper
        let wrapper = CrashlyticsWrapper(options: options)

        // then the crashlytics instance is found correctly
        wait(delay: .longTimeout)

        XCTAssertNotNil(wrapper.instance)
        XCTAssertNotNil(wrapper.instance as? MockCrashlytics)
    }

    func test_setCustomValue() throws {
        // given a mock crashlytics instance
        let mock = MockCrashlytics()
        MockCrashlytics.instance = mock

        // when initializing a crashlytics wrapper
        let wrapper = CrashlyticsWrapper(options: options)
        wait(delay: .longTimeout)

        // when setting the current session id and sdk versions
        wrapper.setCustomValue(key: CrashReporterInfoKey.sessionId, value: "test")
        wrapper.setCustomValue(key: CrashReporterInfoKey.sdkVersion, value: "test")

        // then setCustomValue:forKey is called on crashlytics
        XCTAssertEqual(mock.setCustomValueCallCount, 2)
    }
}
