//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceAtomicsShim
@testable import EmbraceCommonInternal

final class EmbraceAtomicTests: XCTestCase {

    // MARK: - Integer suites (signed & unsigned)

    func test_Int8_basicOps() { runIntegerSuite(initial: Int8(1), delta: 2) }
    func test_Int16_basicOps() { runIntegerSuite(initial: Int16(1), delta: 2) }
    func test_Int32_basicOps() { runIntegerSuite(initial: Int32(1), delta: 2) }
    func test_Int64_basicOps() { runIntegerSuite(initial: Int64(1), delta: 2) }

    func test_UInt8_basicOps() { runIntegerSuite(initial: UInt8(1), delta: 2) }
    func test_UInt16_basicOps() { runIntegerSuite(initial: UInt16(1), delta: 2) }
    func test_UInt32_basicOps() { runIntegerSuite(initial: UInt32(1), delta: 2) }
    func test_UInt64_basicOps() { runIntegerSuite(initial: UInt64(1), delta: 2) }

    // MARK: - Bool suite

    func test_Bool_basicOps() {
        let b = EmbraceAtomic<Bool>(false)

        XCTAssertFalse(b.load())
        b.store(true, order: .release)
        XCTAssertTrue(b.load(order: .acquire))

        let old = b.exchange(false, order: .acqRel)
        XCTAssertTrue(old)
        XCTAssertFalse(b.load())

        var expected = false
        XCTAssertTrue(
            b.compareExchange(
                expected: &expected,
                desired: true,
                successOrder: .release,
                failureOrder: .acquire)
        )
        XCTAssertTrue(b.load())

        // Failure path updates expected
        var expFail = false
        XCTAssertFalse(
            b.compareExchange(
                expected: &expFail,
                desired: false,
                successOrder: .release,
                failureOrder: .acquire)
        )
        XCTAssertEqual(expFail, true)
        XCTAssertTrue(b.load())
    }

    // MARK: - Concurrency smoke tests

    func test_Int64_concurrentIncrements() {
        let iterations = 100_000
        let threads = max(2, ProcessInfo.processInfo.processorCount)
        let perThread = iterations / threads
        let counter = EmbraceAtomic<Int64>(0)

        DispatchQueue.concurrentPerform(iterations: threads) { _ in
            for _ in 0..<perThread { _ = counter.fetchAdd(1, order: .acqRel) }
        }

        XCTAssertEqual(counter.load(order: .seqCst), Int64(perThread * threads))
    }

    func test_MemoryOrder_variants_compile() {
        let a = EmbraceAtomic<Int32>(123)
        _ = a.load(order: .relaxed)
        a.store(1, order: .release)
        _ = a.exchange(2, order: .acquire)
        var exp: Int32 = 2
        _ = a.compareExchange(expected: &exp, desired: 3, successOrder: .acqRel, failureOrder: .acquire)
    }
}

//
// MARK: - Helper
//

/// Common test for integer types covering: init/load/store/exchange/CAS/fetchAdd/fetchSub
private func runIntegerSuite<T>(
    initial: T,
    delta: T,
    order: MemoryOrder = .seqCst
)
where T: FixedWidthInteger & EmbraceAtomicArithmetic {
    let a = EmbraceAtomic<T>(initial)

    // load
    XCTAssertEqual(a.load(order: order), initial)

    // store (use typed literal to avoid Int-to-T conversion and use wrapping ops for both signed & unsigned)
    a.store(initial &* T(3), order: .release)
    XCTAssertEqual(a.load(order: .acquire), initial &* T(3))

    // exchange
    let old = a.exchange(initial, order: .acqRel)
    XCTAssertEqual(old, initial &* T(3))
    XCTAssertEqual(a.load(), initial)

    // fetchAdd / fetchSub
    let preAdd = a.fetchAdd(delta, order: .acqRel)
    XCTAssertEqual(preAdd, initial)
    XCTAssertEqual(a.load(), initial &+ delta)

    let preSub = a.fetchSub(delta, order: .acqRel)
    XCTAssertEqual(preSub, initial &+ delta)
    XCTAssertEqual(a.load(), initial)

    // compareExchange success
    var expected = initial
    XCTAssertTrue(
        a.compareExchange(
            expected: &expected,
            desired: initial &+ T(1),
            successOrder: .release,
            failureOrder: .acquire)
    )
    XCTAssertEqual(a.load(), initial &+ T(1))

    // compareExchange failure updates expected
    var expectedFail = initial
    XCTAssertFalse(
        a.compareExchange(
            expected: &expectedFail,
            desired: initial &+ T(2),
            successOrder: .release,
            failureOrder: .acquire)
    )
    XCTAssertEqual(expectedFail, initial &+ T(1))
    XCTAssertEqual(a.load(), initial &+ T(1))
}

final class EmbraceAtomicExtrasTests: XCTestCase {

    // MARK: - Bool.toggle()

    func testToggleReturnsOldAndFlips() {
        let flag = EmbraceAtomic<Bool>(false)

        let old0 = flag.toggle()  // returns old (false), new becomes true
        XCTAssertEqual(old0, true)
        XCTAssertEqual(flag.load(), true)

        let old1 = flag.toggle(.seqCst)  // explicit order
        XCTAssertEqual(old1, false)
        XCTAssertEqual(flag.load(), false)

        let old2 = flag.toggle(.acqRel)
        XCTAssertEqual(old2, true)
        XCTAssertEqual(flag.load(), true)
    }

    func testToggleConcurrentlyIsLinearizable() {
        let flag = EmbraceAtomic<Bool>(false)
        let iterations = 10_000
        let group = DispatchGroup()
        let q = DispatchQueue(label: "toggle.concurrent", attributes: .concurrent)

        for _ in 0..<iterations {
            group.enter()
            q.async {
                _ = flag.toggle(.acqRel)
                group.leave()
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 5), .success, "Concurrent toggles timed out")

        // After even number of toggles, value should be original (false)
        // After odd number, it should be inverted (true)
        XCTAssertEqual(flag.load(), iterations % 2 == 1)
    }

    // MARK: - ExpressibleByIntegerLiteral / ExpressibleByBooleanLiteral

    func testExpressibleByIntegerLiteral() {
        let a: EmbraceAtomic<Int32> = 42
        XCTAssertEqual(a.load(), 42)
    }

    func testExpressibleByBooleanLiteral() {
        let flag: EmbraceAtomic<Bool> = true
        XCTAssertEqual(flag.load(), true)
    }

    // MARK: - CustomStringConvertible

    func testCustomStringConvertibleReflectsValue() {
        let a: EmbraceAtomic<Int32> = 7
        XCTAssertEqual(a.description, "7")

        let flag: EmbraceAtomic<Bool> = false
        XCTAssertEqual(flag.description, "false")
    }

    // MARK: - Equatable

    func testEquatableComparesByValue() {
        let a = EmbraceAtomic<Int32>(10)
        let b = EmbraceAtomic<Int32>(10)
        let c = EmbraceAtomic<Int32>(11)

        XCTAssertTrue(a == b)
        XCTAssertFalse(a == c)

        b.store(12)
        XCTAssertFalse(a == b)
    }

    // MARK: - Codable

    func testCodableRoundTrip_Int32() throws {
        let original = EmbraceAtomic<Int32>(123)
        let data = try JSONEncoder().encode(original)

        let decoded = try JSONDecoder().decode(EmbraceAtomic<Int32>.self, from: data)
        XCTAssertEqual(decoded.load(), 123)
    }

    func testCodableRoundTrip_Bool() throws {
        let original = EmbraceAtomic<Bool>(true)
        let data = try JSONEncoder().encode(original)

        let decoded = try JSONDecoder().decode(EmbraceAtomic<Bool>.self, from: data)
        XCTAssertEqual(decoded.load(), true)
    }

    // MARK: - @unchecked Sendable sanity

    func testSendableCrossThreadAccess() async {
        let a = EmbraceAtomic<Int32>(0)

        // Read/modify across detached tasks to ensure no obvious crashes / data races.
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<1_000 {
                group.addTask {
                    // Perform a few loads/stores/exchanges
                    let v = a.load()
                    if v % 2 == 0 {
                        _ = a.exchange(v + 1)
                    } else {
                        a.store(v - 1)
                    }
                }
            }
        }

        // We can't assert an exact value (nondeterministic),
        // but we can assert that it’s a valid Int32 and the operations didn’t crash.
        _ = a.load()
    }

    // MARK: - Description / Codable stability across mutations

    func testDescriptionAndCodableReflectLatestValue() throws {
        let a = EmbraceAtomic<Int32>(5)
        XCTAssertEqual(a.description, "5")

        a.store(9)
        XCTAssertEqual(a.description, "9")

        let data = try JSONEncoder().encode(a)
        let s = String(data: data, encoding: .utf8)!
        XCTAssertTrue(s.contains("9"), "Encoded JSON should contain latest value")

        let b = try JSONDecoder().decode(EmbraceAtomic<Int32>.self, from: data)
        XCTAssertEqual(b.load(), 9)
    }
}
