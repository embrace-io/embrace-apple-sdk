//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public enum AppResourceKey: String, Codable {
    case bundleVersion = "emb.app.bundle_version"
    case environment = "emb.app.environment"
    case detailedEnvironment = "emb.app.environment_detailed"
    case framework = "emb.app.framework"
    case launchCount = "emb.app.launch_count"
    case appVersion = "emb.app.version"

    case sdkVersion = "emb.sdk.version"
}
