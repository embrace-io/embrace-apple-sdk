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

    private func resolve(
        _ decision: EmbraceNetworkSpanParent,
        header: W3C.ParsedTraceparent?,
        networkSpanParent: EmbraceSpanContext?
    ) -> NetworkSpanParentResolver.Resolution {
        return NetworkSpanParentResolver.resolve(
            decision: decision,
            header: header,
            networkSpanParent: networkSpanParent
        )
    }

    /// Every combination of decision, header and network span parent, with the parent and source each one resolves to.
    func test_allCombinations() {
        let invalid = EmbraceSpanContext(spanId: "0000000000000000", traceId: chosen.traceId)
        let decisions: [(name: String, decision: EmbraceNetworkSpanParent)] = [
            ("default", .default),
            ("noParent", .noParent),
            ("valid parent", .parent(chosen)),
            ("invalid parent", .parent(invalid))
        ]

        for (name, decision) in decisions {
            for header in [nil, self.header] {
                for networkSpanParent in [nil, self.networkSpanParent] {
                    let expected: (context: EmbraceSpanContext?, source: NetworkSpanParentResolver.Source)
                    switch decision {
                    case .noParent:
                        expected = (nil, .dataSource)
                    case .parent(let context) where context.isValid:
                        expected = (chosen, .dataSource)
                    default:
                        if let header {
                            expected = (header.context, .header)
                        } else if let networkSpanParent {
                            expected = (networkSpanParent, .networkSpanParent)
                        } else {
                            expected = (nil, .none)
                        }
                    }

                    let resolution = resolve(decision, header: header, networkSpanParent: networkSpanParent)

                    let message = "decision: \(name), header: \(header != nil), network span parent: \(networkSpanParent != nil)"
                    XCTAssertEqual(resolution.context?.spanId, expected.context?.spanId, message)
                    XCTAssertEqual(resolution.context?.traceId, expected.context?.traceId, message)
                    XCTAssertEqual(resolution.source, expected.source, message)
                    XCTAssertEqual(resolution.ignoredInvalidParent?.spanId, name == "invalid parent" ? invalid.spanId : nil, message)
                }
            }
        }
    }

    func test_parent_isNormalized() {
        let uppercase = EmbraceSpanContext(spanId: chosen.spanId.uppercased(), traceId: chosen.traceId.uppercased())
        let resolution = resolve(.parent(uppercase), header: nil, networkSpanParent: nil)
        XCTAssertEqual(resolution.context?.spanId, chosen.spanId)
        XCTAssertEqual(resolution.context?.traceId, chosen.traceId)
    }
}
