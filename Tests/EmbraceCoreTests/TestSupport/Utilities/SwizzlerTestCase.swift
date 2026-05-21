//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

/// Base class for tests that touch the global `SwizzleCache`. Captures a baseline
/// snapshot in `setUp` and asserts no new entries remain in `tearDown` — a swizzler
/// install without a matching unswizzle fails at the test that caused it, not as
/// cross-class residue downstream.
///
/// Subclasses that override `tearDownWithError` must call `try super.tearDownWithError()`
/// after their own cleanup so the assertion runs against post-cleanup state. Capture-
/// service tests that install via `EmbraceSwizzler` directly (no uninstall API) call
/// `restoreSwizzleCacheAdditions()` before `super` to drain what they added.
open class SwizzlerTestCase: XCTestCase {
    open override func setUpWithError() throws {
        try super.setUpWithError()
        captureSwizzleCacheBaseline()
    }

    open override func tearDownWithError() throws {
        try super.tearDownWithError()
        assertNoNewSwizzleCacheEntries()
    }
}
