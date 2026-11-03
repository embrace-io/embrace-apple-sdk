//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

final class NetworkSpanParentResolverTests: XCTestCase {

    private let header = W3C.ParsedTraceparent(
        traceId: "4bf92f3577b34da6a3ce929d0e0e4736",
        spanId: "00f067aa0ba902b7",
        flags: "01"
    )
    private let networkSpanParent = EmbraceSpanContext(spanId: .randomSpanId(), traceId: .randomTraceId())
    private let chosen = EmbraceSpanContext(spanId: .randomSpanId(), traceId: .randomTraceId())
    private var logger: MockLogger!

    override func setUp() {
        logger = MockLogger()
    }

    private func resolve(
        _ decision: EmbraceNetworkSpanParent,
        header: W3C.ParsedTraceparent?,
        networkSpanParent: EmbraceSpanContext?
    ) -> NetworkSpanParentResolver.Resolution {
        return NetworkSpanParentResolver.resolve(
            decision: decision,
            header: header,
            networkSpanParent: networkSpanParent,
            logger: logger
        )
    }

    func test_nothingSet_isRoot() {
        let resolution = resolve(.default, header: nil, networkSpanParent: nil)
        XCTAssertNil(resolution.context)
        XCTAssertEqual(resolution.source, .none)
    }

    func test_networkSpanParentOnly_isNetworkSpanParent() {
        let resolution = resolve(.default, header: nil, networkSpanParent: networkSpanParent)
        XCTAssertEqual(resolution.context?.spanId, networkSpanParent.spanId)
        XCTAssertEqual(resolution.source, .networkSpanParent)
    }

    func test_headerAndNetworkSpanParent_headerWins() {
        let resolution = resolve(.default, header: header, networkSpanParent: networkSpanParent)
        XCTAssertEqual(resolution.context?.spanId, header.spanId)
        XCTAssertEqual(resolution.context?.traceId, header.traceId)
        XCTAssertEqual(resolution.source, .header)
    }

    func test_parent_winsOverHeaderAndNetworkSpanParent() {
        let resolution = resolve(.parent(chosen), header: header, networkSpanParent: networkSpanParent)
        XCTAssertEqual(resolution.context?.spanId, chosen.spanId)
        XCTAssertEqual(resolution.context?.traceId, chosen.traceId)
        XCTAssertEqual(resolution.source, .dataSource)
    }

    func test_noParent_winsOverHeaderAndNetworkSpanParent() {
        let resolution = resolve(.noParent, header: header, networkSpanParent: networkSpanParent)
        XCTAssertNil(resolution.context)
        XCTAssertEqual(resolution.source, .dataSource)
    }

    func test_parent_isNormalized() {
        let uppercase = EmbraceSpanContext(spanId: chosen.spanId.uppercased(), traceId: chosen.traceId.uppercased())
        let resolution = resolve(.parent(uppercase), header: nil, networkSpanParent: nil)
        XCTAssertEqual(resolution.context?.spanId, chosen.spanId)
        XCTAssertEqual(resolution.context?.traceId, chosen.traceId)
    }

    func test_invalidParent_isTreatedAsDefault_andLogged() {
        let invalid = EmbraceSpanContext(spanId: "0000000000000000", traceId: chosen.traceId)

        let withHeader = resolve(.parent(invalid), header: header, networkSpanParent: networkSpanParent)
        XCTAssertEqual(withHeader.context?.spanId, header.spanId)
        XCTAssertEqual(withHeader.source, .header)

        let withNetworkSpanParent = resolve(.parent(invalid), header: nil, networkSpanParent: networkSpanParent)
        XCTAssertEqual(withNetworkSpanParent.context?.spanId, networkSpanParent.spanId)
        XCTAssertEqual(withNetworkSpanParent.source, .networkSpanParent)

        let warnings = logger.loggedMessages.filter { $0.level == .warning }
        XCTAssertEqual(warnings.count, 2)
    }
}
