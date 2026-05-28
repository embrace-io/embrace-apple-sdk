//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

internal enum HostAllowlistMatcher {

    /// Returns whether `host` is permitted by `allowlist`.
    ///
    /// - `allowlist` Empty -> false (ignore all requests).
    /// - `host` nil → false.
    /// - Otherwise: case-insensitive match on equality (`"test.com"`) or subdomain
    ///   (`"api.test.com"` for entry `"test.com"`). Entries are expected to be
    ///   lowercase-normalized at Options-init time.
    static func matches(host: String?, allowlist: [String]) -> Bool {
        guard !allowlist.isEmpty else { return false }
        guard let host else { return false }

        let lowerHost = host.lowercased()
        for entry in allowlist {
            if lowerHost == entry { return true }
            if lowerHost.hasSuffix("." + entry) { return true }
        }
        return false
    }
}
