//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal

extension CrashReporterContext {
    public static var testContext: CrashReporterContext {
        CrashReporterContext(
            appId: TestConstants.appId,
            sdkVersion: TestConstants.sdkVersion,
            filePathProvider: TemporaryFilepathProvider(),
            notificationCenter: NotificationCenter.default
        )
    }
}
