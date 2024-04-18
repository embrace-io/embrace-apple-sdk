//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceIO

extension BrandGameApp {

    func addGitInfoProperties() {
        guard let info = GitInfo.fromInfoPlist() else {
            return
        }

        guard let metadata = Embrace.client?.metadata else {
            return
        }

        if let branch = info.branch {
            try? metadata.addProperty(key: "git.branch", value: branch, lifespan: .process)
        }

        if let sha = info.sha {
            try? metadata.addProperty(key: "git.sha", value: sha, lifespan: .process)
        }

        if let dirtyCount = info.dirtyFileCount {
            try? metadata.addProperty(key: "git.dirty_file_count", value: String(dirtyCount), lifespan: .process)
        }
    }

}
