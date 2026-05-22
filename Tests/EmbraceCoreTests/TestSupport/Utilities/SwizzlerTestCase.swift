//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import ObjectiveC.runtime
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

extension XCTestCase {
    /// Records the current global `SwizzleCache` contents as a per-test baseline. Call from
    /// `setUp` / `setUpWithError`. `assertNoNewSwizzleCacheEntries` and
    /// `restoreSwizzleCacheAdditions` use this baseline to ignore residue left by earlier
    /// test classes — a leak surfaces at the test that actually caused it.
    public func captureSwizzleCacheBaseline() {
        let baseline = Set(SwizzleCache.shared.residueDescription)
        objc_setAssociatedObject(self, &swizzleCacheBaselineKey, baseline, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    /// Asserts no swizzler entries were added to the global `SwizzleCache` since the baseline
    /// recorded by `captureSwizzleCacheBaseline`. Call from `tearDownWithError`. If no baseline
    /// was recorded the comparison treats the baseline as empty.
    public func assertNoNewSwizzleCacheEntries(file: StaticString = #file, line: UInt = #line) {
        let added = newSwizzleCacheEntries()
        XCTAssertTrue(
            added.isEmpty,
            "SwizzleCache leak after \(name): \(added.joined(separator: ", "))",
            file: file,
            line: line
        )
    }

    /// Restores the original IMPs for every cache entry added since the baseline and removes
    /// them from the cache. Intended for capture-service tests that install via `EmbraceSwizzler`
    /// directly and have no uninstall API — call from `tearDownWithError` before
    /// `assertNoNewSwizzleCacheEntries`.
    public func restoreSwizzleCacheAdditions() {
        SwizzleCache.shared.restoreEntries(addedSince: swizzleCacheBaseline())
    }

    private func swizzleCacheBaseline() -> Set<String> {
        (objc_getAssociatedObject(self, &swizzleCacheBaselineKey) as? Set<String>) ?? []
    }

    private func newSwizzleCacheEntries() -> [String] {
        let baseline = swizzleCacheBaseline()
        return SwizzleCache.shared.residueDescription.filter { !baseline.contains($0) }
    }
}

private nonisolated(unsafe) var swizzleCacheBaselineKey: UInt8 = 0
