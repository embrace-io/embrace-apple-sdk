//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Releases a `DispatchGroup` exactly once, no matter how many times `release()` is called.
///
/// `DispatchGroup` traps the process on an unbalanced `leave()`, which makes "leave from every
/// exit path" unsafe to write directly: any path that can run twice, or that can run after
/// another path already left, takes the app down. Wrapping the balance in one place makes the
/// call site safe to sprinkle wherever a group must be released.
package final class OneShotGroupRelease {

    private let group: DispatchGroup
    private let released = EmbraceMutex(false)

    /// Whether the group has already been released.
    package var hasReleased: Bool {
        released.withLock { $0 }
    }

    package init(_ group: DispatchGroup) {
        self.group = group
    }

    /// Leaves the group if it has not been left already. Safe to call from any thread, and
    /// safe to call repeatedly.
    package func release() {
        let shouldLeave = released.withLock { released -> Bool in
            guard !released else { return false }
            released = true
            return true
        }

        if shouldLeave {
            group.leave()
        }
    }
}
