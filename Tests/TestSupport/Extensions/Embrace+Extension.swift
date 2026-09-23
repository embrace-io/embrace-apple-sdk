//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@testable import EmbraceCore

extension Embrace {
    /// Sets up and starts a client with no capture services, no crash reporter and no network
    /// access, for suites that need a started SDK but don't test it.
    ///
    /// Leaving out the app id gives the client a static configuration and no endpoints, so it
    /// starts no remote-config fetch and makes no uploads. A fetch in flight would read SDK
    /// globals on a background thread while a later suite's `setup` writes them.
    public static func startWithoutNetwork() {
        _ = try? Embrace.setup(options: Embrace.Options(captureServices: [], crashReporter: nil)).start()
    }

    /// Stops the current client and clears it, so the next `setup` creates a new one.
    public static func stopAndClearClient() {
        _ = try? Embrace.client?.stop()
        Embrace.client = nil
    }
}
