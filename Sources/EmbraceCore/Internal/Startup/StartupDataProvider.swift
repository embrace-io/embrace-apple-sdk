//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

enum StartupType: String {
    case cold
    case warm
}

protocol StartupDataProvider {
    var startupType: StartupType { get }
    var isPrewarm: Bool { get }

    var processStartTime: Date? { get }
    var constructorClosestToMainTime: Date { get }

    var firstFrameTime: Date? { get }
    var onFirstFrameTimeSet: ((Date) -> Void)? { get set }

    var appDidFinishLaunchingEndTime: Date? { get }
    var onAppDidFinishLaunchingEndTimeSet: ((Date) -> Void)? { get set }

    var sdkSetupStartTime: Date? { get }
    var sdkSetupEndTime: Date? { get }
    var sdkStartStartTime: Date? { get }
    var sdkStartEndTime: Date? { get }
}
