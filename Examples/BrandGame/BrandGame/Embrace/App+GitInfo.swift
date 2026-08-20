//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceIO

extension BrandGameApp {

    func addGitInfoProperties() {
        guard let info = GitInfo.fromInfoPlist() else {
            return
        }

        if let branch = info.branch {
            EmbraceIO.shared.setProperty(key: "git.branch", value: branch, lifespan: .process)
        }

        if let sha = info.sha {
            EmbraceIO.shared.setProperty(key: "git.sha", value: sha, lifespan: .process)
        }

        if let dirtyCount = info.dirtyFileCount {
            EmbraceIO.shared.setProperty(key: "git.dirty_file_count", value: String(dirtyCount), lifespan: .process)
        }
    }

}
