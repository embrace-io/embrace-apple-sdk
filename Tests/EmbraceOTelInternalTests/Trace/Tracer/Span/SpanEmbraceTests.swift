//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import OpenTelemetryApi
import TestSupport
import XCTest

@testable import EmbraceOTelInternal
@testable import OpenTelemetrySdk

final class SpanEmbraceTests: XCTestCase {
    private enum LocalizedOnlyError: LocalizedError {
        case somethingFailed

        var errorDescription: String? {
            "Something failed with a custom description"
        }
    }

    private enum PlainError: Error {
        case generic
    }

    private enum BothProtocolsError: LocalizedError, CustomNSError {
        case dual

        var errorDescription: String? {
            "Localized message"
        }

        static var errorDomain: String { "BothProtocolsError" }
        var errorCode: Int { 42 }
        var errorUserInfo: [String: Any] {
            [NSLocalizedDescriptionKey: "NSError message"]
        }
    }

    // MARK: - Tests

    func test_endWithLocalizedError_usesErrorDescription() {
        let span = createSpan()

        span.end(error: LocalizedOnlyError.somethingFailed)

        let attributes = span.toSpanData().attributes
        XCTAssertEqual(
            attributes[SpanSemantics.keyNSErrorMessage]?.description,
            "Something failed with a custom description"
        )
        XCTAssertEqual(
            attributes[SpanSemantics.keyErrorCode]?.description,
            SpanErrorCode.failure.rawValue
        )
    }

    func test_endWithPlainError_usesLocalizedDescriptionWithoutIssue() throws {
        let span = createSpan()

        span.end(error: PlainError.generic)

        let attributes = span.toSpanData().attributes
        let message = attributes[SpanSemantics.keyNSErrorMessage]?.description
        let unwrappedMessage = try XCTUnwrap(message)
        XCTAssertFalse(unwrappedMessage.isEmpty)
    }

    func test_endWithNSError_usesLocalizedDescription() {
        let span = createSpan()
        let nsError = NSError(
            domain: "TestDomain",
            code: 123,
            userInfo: [
                NSLocalizedDescriptionKey: "NSError custom message"
            ]
        )

        span.end(error: nsError)

        let attributes = span.toSpanData().attributes
        XCTAssertEqual(
            attributes[SpanSemantics.keyNSErrorMessage]?.description,
            "NSError custom message"
        )
        XCTAssertEqual(
            attributes[SpanSemantics.keyNSErrorCode]?.description,
            "123"
        )
    }

    func test_endWithBothProtocols_prefersLocalizedErrorOverNSError() {
        let span = createSpan()

        span.end(error: BothProtocolsError.dual)

        let attributes = span.toSpanData().attributes
        XCTAssertEqual(
            attributes[SpanSemantics.keyNSErrorMessage]?.description,
            "Localized message"
        )
        XCTAssertEqual(
            attributes[SpanSemantics.keyNSErrorCode]?.description,
            "42"
        )
    }

    func test_endWithNilError_setsStatusOk() {
        let span = createSpan()

        span.end(error: nil)

        let attributes = span.toSpanData().attributes
        XCTAssertNil(attributes[SpanSemantics.keyNSErrorMessage])
        XCTAssertNil(attributes[SpanSemantics.keyNSErrorCode])
        XCTAssertEqual(span.toSpanData().status, .ok)
    }

    func test_endWithError_setsErrorCode() {
        let span = createSpan()

        span.end(error: PlainError.generic, errorCode: .userAbandon)

        let attributes = span.toSpanData().attributes
        XCTAssertEqual(
            attributes[SpanSemantics.keyErrorCode]?.description,
            SpanErrorCode.userAbandon.rawValue
        )
    }
}

extension SpanEmbraceTests {
    fileprivate func createSpan() -> SpanSdk {
        let processor = NoopSpanProcessor()
        return SpanSdk.startSpan(
            context: .create(
                traceId: .random(),
                spanId: .random(),
                traceFlags: .init(),
                traceState: .init()
            ),
            name: "test-span",
            instrumentationScopeInfo: .init(),
            kind: .client,
            parentContext: nil,
            hasRemoteParent: false,
            spanLimits: .init(),
            spanProcessor: processor,
            clock: MillisClock(),
            resource: Resource(),
            attributes: .init(capacity: 10),
            links: [],
            totalRecordedLinks: 0,
            startTime: Date()
        )
    }
}
