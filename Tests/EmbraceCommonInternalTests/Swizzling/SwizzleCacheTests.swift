//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import ObjectiveC.runtime
import XCTest

@testable import EmbraceCommonInternal

final class SwizzleCacheTests: XCTestCase {

    @objc private class DummySwizzleTarget: NSObject {
        @objc dynamic func dummyMethod() {}
    }

    private struct TestSwizzler: Swizzlable {
        typealias ImplementationType = @convention(c) (AnyObject, Selector) -> Void
        typealias BlockImplementationType = @convention(block) (AnyObject) -> Void
        static let selector: Selector = #selector(DummySwizzleTarget.dummyMethod)
        let baseClass: AnyClass = DummySwizzleTarget.self

        func install() throws {
            try swizzleInstanceMethod { original -> BlockImplementationType in
                return { receiver in original(receiver, Self.selector) }
            }
        }
    }

    private var method: Method!
    private var trueOriginalIMP: IMP!
    private let swizzlerName = "TestSwizzler"
    private var duplicateInstallMessages: [String] = []
    private var originalDuplicateHandler: ((String) -> Void)!

    override func setUpWithError() throws {
        XCTAssertTrue(
            SwizzleCache.shared.isEmpty,
            "test pollution from prior tests: \(SwizzleCache.shared.residueDescription)"
        )
        method = try XCTUnwrap(
            class_getInstanceMethod(DummySwizzleTarget.self, #selector(DummySwizzleTarget.dummyMethod))
        )
        trueOriginalIMP = method_getImplementation(method)
        duplicateInstallMessages = []
        originalDuplicateHandler = SwizzleCache.onDuplicateInstall
        SwizzleCache.onDuplicateInstall = { [weak self] message in
            self?.duplicateInstallMessages.append(message)
        }
    }

    override func tearDownWithError() throws {
        SwizzleCache.shared.removeOriginalMethodImplementation(
            forMethod: method, inClass: DummySwizzleTarget.self, swizzler: swizzlerName)
        SwizzleCache.shared.removeOriginalMethodImplementation(
            forMethod: method, inClass: DummySwizzleTarget.self, swizzler: "SwizzlerA")
        SwizzleCache.shared.removeOriginalMethodImplementation(
            forMethod: method, inClass: DummySwizzleTarget.self, swizzler: "SwizzlerB")
        method_setImplementation(method, trueOriginalIMP)
        SwizzleCache.onDuplicateInstall = originalDuplicateHandler
    }

    /// Duplicate installs without an unswizzle in between must not overwrite the cached "true
    /// original" with an already-swizzled IMP — otherwise a later unswizzle would restore stale
    /// state.
    func test_duplicateInstall_preservesTrueOriginalImplementation() {
        let stalePostSwizzleIMP = imp_implementationWithBlock(({} as @convention(block) () -> Void))
        addToCache(trueOriginalIMP)
        addToCache(stalePostSwizzleIMP)

        let cached = SwizzleCache.shared.getOriginalMethodImplementation(
            forMethod: method,
            inClass: DummySwizzleTarget.self,
            swizzler: swizzlerName
        )
        XCTAssertEqual(cached, trueOriginalIMP)
        XCTAssertNotEqual(cached, stalePostSwizzleIMP)
        XCTAssertEqual(SwizzleCache.shared.residueDescription.count, 1)
        XCTAssertEqual(duplicateInstallMessages.count, 1)
        XCTAssertTrue(duplicateInstallMessages[0].contains(swizzlerName))
        imp_removeBlock(stalePostSwizzleIMP)
    }

    /// A swizzler that unswizzles between installs is the legitimate cross-test scenario — the
    /// second install must succeed (not be misclassified as a leak).
    func test_installAfterRemove_treatsSecondInstallAsFirst() {
        let firstIMP = trueOriginalIMP!
        let secondIMP = imp_implementationWithBlock(({} as @convention(block) () -> Void))

        addToCache(firstIMP)
        SwizzleCache.shared.removeOriginalMethodImplementation(
            forMethod: method,
            inClass: DummySwizzleTarget.self,
            swizzler: swizzlerName
        )
        addToCache(secondIMP)

        let cached = SwizzleCache.shared.getOriginalMethodImplementation(
            forMethod: method,
            inClass: DummySwizzleTarget.self,
            swizzler: swizzlerName
        )
        XCTAssertEqual(cached, secondIMP)
        XCTAssertEqual(duplicateInstallMessages.count, 0)
        imp_removeBlock(secondIMP)
    }

    /// Cache keys are `(method, baseClass, swizzlerClass)`. Two different swizzler classes
    /// targeting the same method must both be able to install once.
    func test_duplicateRejection_isScopedToSwizzlerClass() {
        addToCache(trueOriginalIMP, swizzler: "SwizzlerA")
        let otherIMP = imp_implementationWithBlock(({} as @convention(block) () -> Void))
        addToCache(otherIMP, swizzler: "SwizzlerB")

        XCTAssertEqual(
            SwizzleCache.shared.getOriginalMethodImplementation(
                forMethod: method, inClass: DummySwizzleTarget.self, swizzler: "SwizzlerA"),
            trueOriginalIMP
        )
        XCTAssertEqual(
            SwizzleCache.shared.getOriginalMethodImplementation(
                forMethod: method, inClass: DummySwizzleTarget.self, swizzler: "SwizzlerB"),
            otherIMP
        )
        XCTAssertEqual(duplicateInstallMessages.count, 0)
        imp_removeBlock(otherIMP)
    }

    /// End-to-end: the user-visible contract is that unswizzle restores the method's IMP to the
    /// pre-first-swizzle IMP, even when a duplicate install corrupted the live method chain in
    /// between. Exercises `Swizzlable.swizzleInstanceMethod` (not just the cache directly) so any
    /// future changes that decoupled the cache from unswizzle would be caught.
    func test_endToEnd_unswizzleAfterDuplicateInstall_restoresTrueOriginal() throws {
        let swizzler = TestSwizzler()

        try swizzler.install()
        let firstSwizzledIMP = method_getImplementation(method)
        XCTAssertNotEqual(firstSwizzledIMP, trueOriginalIMP)

        try swizzler.install()
        XCTAssertEqual(duplicateInstallMessages.count, 1)

        let cachedOriginal = try XCTUnwrap(
            SwizzleCache.shared.getOriginalMethodImplementation(
                forMethod: method,
                inClass: DummySwizzleTarget.self,
                swizzler: String(describing: TestSwizzler.self)
            )
        )
        XCTAssertEqual(cachedOriginal, trueOriginalIMP)

        method_setImplementation(method, cachedOriginal)
        XCTAssertEqual(method_getImplementation(method), trueOriginalIMP)
    }

    private func addToCache(_ imp: IMP, swizzler: String? = nil) {
        SwizzleCache.shared.addMethodImplementation(
            imp,
            forMethod: method,
            inClass: DummySwizzleTarget.self,
            swizzler: swizzler ?? swizzlerName
        )
    }
}
