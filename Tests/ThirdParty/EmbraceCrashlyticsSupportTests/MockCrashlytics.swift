//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@objc(MockCrashlytics) class MockCrashlytics: NSObject {
    nonisolated(unsafe) static var instance: MockCrashlytics?

    @objc class func sharedInstance() -> MockCrashlytics? {
        return MockCrashlytics.instance
    }

    private(set) var setCustomValueCallCount: Int = 0

    @objc func setCustomValue(_ value: String, forKey key: String) {
        setCustomValueCallCount += 1
    }
}
