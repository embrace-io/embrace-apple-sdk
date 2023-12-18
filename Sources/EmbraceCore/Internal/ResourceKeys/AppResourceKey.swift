//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public enum AppResourceKey: String, Codable {
    case buildUUID = "emb.app.build_uuid"
    case bundleVersion = "emb.app.bundle_version"
    case environment = "emb.app.environment"
    case detailedEnvironment = "emb.app.environment_detailed"
    case framework = "emb.app.framework"
    case launchCount = "emb.app.launch_count"
    case sdkVersion = "emb.app.sdk_version"
    case appVersion = "emb.app.version"
    case bundleId = "emb.app.bundle_id"
}
