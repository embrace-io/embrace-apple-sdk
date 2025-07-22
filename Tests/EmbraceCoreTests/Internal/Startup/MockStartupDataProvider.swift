//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@testable import EmbraceCore

class MockStartupDataProvider: StartupDataProvider {

    var onFirstFrameTimeSet: ((Date) -> Void)?
    var onAppDidFinishLaunchingEndTimeSet: ((Date) -> Void)?

    var startupType: StartupType = .cold
    var isPrewarm: Bool = false
    var processStartTime: Date? = Date(timeIntervalSince1970: 8)
    var constructorClosestToMainTime: Date = Date(timeIntervalSince1970: 10)

    var firstFrameTime: Date? = Date(timeIntervalSince1970: 15) {
        didSet {
            if let firstFrameTime = firstFrameTime {
                onFirstFrameTimeSet?(firstFrameTime)
            }
        }
    }

    var appDidFinishLaunchingEndTime: Date? = Date(timeIntervalSince1970: 14) {
        didSet {
            if let appDidFinishLaunchingEndTime = appDidFinishLaunchingEndTime {
                onAppDidFinishLaunchingEndTimeSet?(appDidFinishLaunchingEndTime)
            }
        }
    }

    var sdkSetupStartTime: Date? = Date(timeIntervalSince1970: 11)
    var sdkSetupEndTime: Date? = Date(timeIntervalSince1970: 12)
    var sdkStartStartTime: Date? = Date(timeIntervalSince1970: 12)
    var sdkStartEndTime: Date? = Date(timeIntervalSince1970: 13)
}
