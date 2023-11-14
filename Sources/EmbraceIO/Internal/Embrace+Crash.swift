//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

extension Embrace {
    func initializeCrashReporter(options: Embrace.Options) {
        // TODO: Handle multiple crash reporters!

        let collectors = options.collectors

        // find crash reporter and set folder path for crashes
        let crashReporter = collection.crashReporter

        if crashReporter == nil {
            print("Not using Embrace's crash reporter")
            return
        }

        let crashesPath = EmbraceFileSystem.crashesDirectoryPath(
            appId: options.appId,
            appGroupId: options.appGroupId
        )?.path

        crashReporter?.configure(appId: options.appId, path: crashesPath)
        crashReporter?.sdkVersion = EmbraceMeta.sdkVersion
    }
}
