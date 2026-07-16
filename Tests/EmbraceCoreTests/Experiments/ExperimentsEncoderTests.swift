//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import Foundation
import XCTest

@testable import EmbraceCore

final class ExperimentsEncoderTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_717_459_200)  // 1717459200000 ms
    private let end = Date(timeIntervalSince1970: 1_717_462_800)  // 1717462800000 ms

    func test_encode_experimentWithVariantAndNoEnd() {
        let experiment = Experiment(id: "abc1", kind: .experiment, variant: "A", startedAt: start, endedAt: nil)
        XCTAssertEqual(ExperimentsEncoder.encode(experiment), "e:abc1:A:1717459200000")
    }

    func test_encode_variantLessFeatureFlag() {
        let flag = Experiment(id: "def2", kind: .featureFlag, variant: nil, startedAt: start, endedAt: nil)
        XCTAssertEqual(ExperimentsEncoder.encode(flag), "f:def2::1717459200000")
    }

    func test_encode_experimentWithEndTime() {
        let experiment = Experiment(id: "abc1", kind: .experiment, variant: "A", startedAt: start, endedAt: end)
        XCTAssertEqual(ExperimentsEncoder.encode(experiment), "e:abc1:A:1717459200000:1717462800000")
    }

    func test_encode_multipleRecordsJoinedInOrder() {
        let experiment = Experiment(id: "abc1", kind: .experiment, variant: "A", startedAt: start, endedAt: nil)
        let flag = Experiment(id: "def2", kind: .featureFlag, variant: nil, startedAt: end, endedAt: nil)
        XCTAssertEqual(
            ExperimentsEncoder.encode([experiment, flag]),
            "e:abc1:A:1717459200000;f:def2::1717462800000"
        )
    }

    func test_encode_escapesReservedCharactersInId() {
        let experiment = Experiment(id: "a:b", kind: .experiment, variant: nil, startedAt: start, endedAt: nil)
        XCTAssertEqual(ExperimentsEncoder.encode(experiment), "e:a%3Ab::1717459200000")
    }

    func test_encode_escapesPercentFirst() {
        // "50%:on" -> escape `%` first (`50%25:on`), then `:` (`50%25%3Aon`)
        let experiment = Experiment(id: "50%:on", kind: .experiment, variant: nil, startedAt: start, endedAt: nil)
        XCTAssertEqual(ExperimentsEncoder.encode(experiment), "e:50%25%3Aon::1717459200000")
    }

    func test_encode_escapesSemicolon() {
        let experiment = Experiment(id: "a;b", kind: .experiment, variant: "x;y", startedAt: start, endedAt: nil)
        XCTAssertEqual(ExperimentsEncoder.encode(experiment), "e:a%3Bb:x%3By:1717459200000")
    }

    func test_encode_leavesPipeLiteral() {
        let experiment = Experiment(id: "abc1", kind: .experiment, variant: "on|off", startedAt: start, endedAt: nil)
        XCTAssertEqual(ExperimentsEncoder.encode(experiment), "e:abc1:on|off:1717459200000")
    }

    func test_encode_emptySetProducesEmptyString() {
        XCTAssertEqual(ExperimentsEncoder.encode([]), "")
    }

    func test_wireTag_mapping() {
        XCTAssertEqual(EmbraceExperimentKind.experiment.wireTag, "e")
        XCTAssertEqual(EmbraceExperimentKind.featureFlag.wireTag, "f")
    }
}
