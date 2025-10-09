//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

enum AppResourceKey: String, Codable {
    case bundleVersion = "emb.app.bundle_version"
    case environment = "emb.app.environment"
    case detailedEnvironment = "emb.app.environment_detailed"
    case framework = "emb.app.framework"
    case launchCount = "emb.app.launch_count"
    case appVersion = "emb.app.version"
    case buildID = "emb.app.build_id"
    case sdkVersion = "emb.sdk.version"
    case processIdentifier = "emb.process_identifier"
    case processStartTime = "emb.process_start_time"
    case processPreWarm = "emb.process_pre_warm"
}
