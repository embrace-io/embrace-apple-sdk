//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

struct GitInfo {
    let branch: String?
    let sha: String?
    let dirtyFileCount: Int?
}

extension GitInfo {
    static func fromInfoPlist() -> GitInfo? {

        if let plistData = Bundle.main.infoDictionary?["GitInfo"] as? [String: Any] {
            return GitInfo(
                branch: plistData["branch"] as? String,
                sha: plistData["sha"] as? String,
                dirtyFileCount: plistData["dirty_count"] as? Int
            )
        }

        return nil
    }
}
