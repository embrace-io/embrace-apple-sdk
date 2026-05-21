//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceCore
import Foundation
import ObjectiveC.runtime
import XCTest

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

extension Swizzlable {
    public func unswizzleInstanceMethod() throws {
        guard let method = class_getInstanceMethod(baseClass, Self.selector) else {
            throw UnswizzleError.noMethodForSelector(value: Self.selector, class: baseClass)
        }
        try unswizzle(method: method)
    }

    public func unswizzleClassMethod() throws {
        guard let method = class_getClassMethod(baseClass, Self.selector) else {
            throw UnswizzleError.noMethodForSelector(value: Self.selector, class: baseClass)
        }
        try unswizzle(method: method)
    }

    private func unswizzle(method: Method) throws {
        let swizzlerClassName = String(describing: type(of: self))
        guard
            let originalImplementation = SwizzleCache.shared.getOriginalMethodImplementation(
                forMethod: method,
                inClass: baseClass,
                swizzler: swizzlerClassName
            )
        else {
            throw UnswizzleError.implementationInCacheNotFound(method: method)
        }
        method_setImplementation(method, originalImplementation)
        SwizzleCache.shared.removeOriginalMethodImplementation(
            forMethod: method,
            inClass: baseClass,
            swizzler: swizzlerClassName
        )
    }
}

enum UnswizzleError: LocalizedError {
    case noMethodForSelector(value: Selector, class: AnyClass)
    case implementationInCacheNotFound(method: Method)

    var errorDescription: String? {
        switch self {
        case .noMethodForSelector(let value, let baseClass):
            return "No method for selector \(value) in class \(type(of: baseClass))"
        case .implementationInCacheNotFound(let method):
            return "No original implmentation of method \(method_getName(method)) was found"
        }
    }
}
