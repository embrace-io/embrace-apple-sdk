//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

    import EmbraceSemantics
    import XCTest

    @testable import EmbraceCore

    /// Covers the registry's two load-bearing properties directly.
    ///
    /// Both are exercised incidentally by the capture-service tests, which is not the same as being
    /// defended by them: the identity guard and the weak reference can both be deleted without a
    /// single one of those failing, because they only matter in situations a service test never
    /// creates — two publishers overlapping, and a publisher outliving its owner.
    final class ManualScreenRegistryTests: XCTestCase {

        private final class SpyReporter: ManualScreenReporting {
            func onManualScreenAppear(
                id: ObjectIdentifier, name: String, attributes: EmbraceAttributes, at time: Date
            ) {}
            func onManualScreenDisappear(id: ObjectIdentifier, name: String, at time: Date) {}
        }

        override func tearDownWithError() throws {
            // Process-global; a value left here would follow the next test into an unrelated suite.
            registrations = []
            try super.tearDownWithError()
        }

        /// Keeps registrations alive for the duration of a test, so nothing withdraws by accident.
        private var registrations: [ManualScreenRegistry.Registration] = []

        // MARK: - Publishing

        func testPublishingMakesTheReporterAvailable() {
            let reporter = SpyReporter()
            registrations.append(ManualScreenRegistry.publish(reporter))

            XCTAssertTrue(ManualScreenRegistry.reporter === reporter)
        }

        func testReleasingTheRegistrationWithdraws() {
            let reporter = SpyReporter()
            var registration: ManualScreenRegistry.Registration? = ManualScreenRegistry.publish(reporter)
            XCTAssertNotNil(ManualScreenRegistry.reporter)

            registration = nil
            _ = registration

            XCTAssertNil(ManualScreenRegistry.reporter, "dropping the token is what un-publishes")
        }

        // MARK: - Replacement

        /// The identity guard's whole reason for existing.
        ///
        /// Without it, the *first* registration's `deinit` clears a reporter it no longer owns, and
        /// the second publisher goes silently dead while still believing it is published.
        func testAStaleRegistrationCannotClearANewerPublisher() {
            let first = SpyReporter()
            let second = SpyReporter()

            var firstRegistration: ManualScreenRegistry.Registration? = ManualScreenRegistry.publish(first)
            registrations.append(ManualScreenRegistry.publish(second))
            XCTAssertTrue(ManualScreenRegistry.reporter === second)

            firstRegistration = nil
            _ = firstRegistration

            XCTAssertTrue(
                ManualScreenRegistry.reporter === second,
                "releasing the displaced registration must not un-publish the current one")
        }

        /// The same guard on the ordinary path: re-publishing from one owner releases the previous
        /// registration, whose `deinit` runs *after* the new one is installed.
        func testRepublishingFromTheSameOwnerStaysPublished() {
            let reporter = SpyReporter()

            var registration = ManualScreenRegistry.publish(reporter)
            registration = ManualScreenRegistry.publish(reporter)
            registrations.append(registration)

            XCTAssertTrue(ManualScreenRegistry.reporter === reporter)
        }

        // MARK: - Lifetime

        /// The registry must never be why a capture service stays alive. Asserts the reporter really
        /// is gone rather than merely unreachable, by checking a weak reference to it.
        func testTheRegistryDoesNotRetainTheReporter() {
            weak var weakReporter: SpyReporter?

            autoreleasepool {
                let reporter = SpyReporter()
                weakReporter = reporter
                registrations.append(ManualScreenRegistry.publish(reporter))
                XCTAssertNotNil(weakReporter)
            }

            XCTAssertNil(weakReporter, "a strong reference here would outlive every SDK instance")
            XCTAssertNil(ManualScreenRegistry.reporter)
        }
    }

#endif
