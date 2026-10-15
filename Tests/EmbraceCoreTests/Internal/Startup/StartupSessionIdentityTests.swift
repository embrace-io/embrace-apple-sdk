//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

/// The startup spans built while `Embrace.start()` runs must carry the identity of the first session part,
/// like every other span recorded during it.
final class StartupSessionIdentityTests: XCTestCase {

    override func setUpWithError() throws {
        Embrace.stopAndClearClient()
    }

    override func tearDownWithError() throws {
        Embrace.stopAndClearClient()
    }

    func test_startupSpans_areStampedWithFirstSessionPart() throws {
        // when the SDK is started
        Embrace.startWithoutNetwork()

        let client = try XCTUnwrap(Embrace.client)
        let session = try XCTUnwrap(client.sessionController.currentSession)
        let userSessionId = try XCTUnwrap(session.userSessionId).stringValue
        let partId = session.id.stringValue

        let (rootSpan, firstFrameSpan) = client.startupInstrumentation.state.withLock { ($0.rootSpan, $0.firstFrameSpan) }

        // then the startup spans are stamped with the first session part
        for span in [try XCTUnwrap(rootSpan), try XCTUnwrap(firstFrameSpan)] {
            XCTAssertEqual(span.attributes[SpanSemantics.keySessionId] as? String, userSessionId, span.name)
            XCTAssertEqual(span.attributes[SpanSemantics.Session.keyUserSessionId] as? String, userSessionId, span.name)
            XCTAssertEqual(span.attributes[SpanSemantics.Session.keyPartId] as? String, partId, span.name)
            XCTAssertEqual(span.sessionId, session.id, span.name)
        }
    }
}
