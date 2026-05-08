//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceOTelInternal

extension EmbraceSpanProcessor {
    /// Test-only barrier that blocks until every prior async work item on `processorQueue` has run.
    /// Use this in tests instead of an `XCTestExpectation` fulfilled from `processorQueue.async { }`.
    public func waitUntilDrained() {
        processorQueue.sync {}
    }
}
