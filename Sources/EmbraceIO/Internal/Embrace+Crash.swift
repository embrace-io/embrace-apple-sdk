//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

extension Embrace {
    func initializeCrashReporter(options: Embrace.Options, collectors: [Collector]) {
        // TODO: Handle multiple crash reporters!

        // find crash reporter and set folder path for crashes
        crashReporter = collectors.first(where: { $0 is CrashReporter }) as? any CrashReporter

        if crashReporter == nil {
            print("Not using Embrace's crash reporter")
            return
        }

        let crashesPath = EmbraceFileSystem.crashesDirectoryPath(
            appId: options.appId,
            appGroupId: options.appGroupId
        )?.path

        crashReporter?.configure(appId: options.appId, path: crashesPath)

        crashReporter?.sdkVersion = "6.0.0" // TODO: Do this properly!
    }
}
