//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore

final class ExperimentsSerializerTests: XCTestCase {

    // 2024-06-04 00:00:00 UTC and 2024-06-04 01:00:00 UTC
    let start = Date(timeIntervalSince1970: 1_717_459_200)
    let end = Date(timeIntervalSince1970: 1_717_462_800)

    private func record(
        _ kind: ExperimentKind = .experiment,
        id: String,
        variant: String? = nil,
        startedAt: Date? = nil,
        endedAt: Date? = nil
    ) -> ExperimentRecord {
        ExperimentRecord(
            kind: kind,
            id: id,
            variant: variant,
            startedAt: startedAt ?? start,
            endedAt: endedAt
        )
    }

    // MARK: - Format

    func test_serialize_activeExperiment() {
        let value = ExperimentsSerializer.serialize([record(id: "abc1", variant: "A")])
        XCTAssertEqual(value, "e:abc1:A:1717459200000")
    }

    func test_serialize_flagWithoutVariant() {
        let value = ExperimentsSerializer.serialize([record(.featureFlag, id: "def2")])
        XCTAssertEqual(value, "f:def2::1717459200000")
    }

    func test_serialize_endedRecord() {
        let value = ExperimentsSerializer.serialize([record(id: "abc1", variant: "A", endedAt: end)])
        XCTAssertEqual(value, "e:abc1:A:1717459200000:1717462800000")
    }

    func test_serialize_multipleRecords_joinedInOrder() {
        let value = ExperimentsSerializer.serialize([
            record(id: "abc1", variant: "A"),
            record(.featureFlag, id: "def2")
        ])
        XCTAssertEqual(value, "e:abc1:A:1717459200000;f:def2::1717459200000")
    }

    func test_serialize_emptyList_isNil() {
        XCTAssertNil(ExperimentsSerializer.serialize([]))
    }

    /// Only `end_ms` is sparse, so a record can never end in a blank field.
    func test_serialize_recordNeverEndsInBlankField() {
        let value = ExperimentsSerializer.serialize([record(id: "abc1", variant: nil)])
        XCTAssertNotNil(value)
        XCTAssertFalse(value!.hasSuffix(":"))
    }

    // MARK: - Variant equivalence

    func test_serialize_nilEmptyAndWhitespaceVariants_produceIdenticalOutput() {
        let fromNil = ExperimentsSerializer.serialize([record(id: "abc1", variant: nil)])
        let fromEmpty = ExperimentsSerializer.serialize([record(id: "abc1", variant: "")])

        XCTAssertEqual(fromNil, fromEmpty)
        XCTAssertEqual(fromNil, "e:abc1::1717459200000")
    }

    // MARK: - Escaping

    func test_escape_separators() {
        XCTAssertEqual(ExperimentsSerializer.escape("a:b"), "a%3Ab")
        XCTAssertEqual(ExperimentsSerializer.escape("a;b"), "a%3Bb")
        XCTAssertEqual(ExperimentsSerializer.escape("100%"), "100%25")
    }

    /// `%` is escaped first, so `a:b` becomes `a%3Ab` and not `a%253Ab`.
    func test_escape_percentIsEscapedFirst() {
        XCTAssertEqual(ExperimentsSerializer.escape("a:b"), "a%3Ab")
        XCTAssertNotEqual(ExperimentsSerializer.escape("a:b"), "a%253Ab")
    }

    /// A literal `%3A` in the input must not survive as something a reader would take for a separator.
    func test_escape_literalEscapeSequenceIsItselfEscaped() {
        XCTAssertEqual(ExperimentsSerializer.escape("%3A"), "%253A")
    }

    func test_escape_leavesOtherCharactersAlone() {
        let untouched = "on|off,v2/beta=1 🚀"
        XCTAssertEqual(ExperimentsSerializer.escape(untouched), untouched)
    }

    func test_serialize_escapesIdAndVariant() {
        let value = ExperimentsSerializer.serialize([record(id: "a:b", variant: "on|off")])
        XCTAssertEqual(value, "e:a%3Ab:on|off:1717459200000")
    }

    /// Every field a record can carry, exercised together and pinned to an exact expected string.
    func test_serialize_valuesNeedingEveryEscape() {
        let value = ExperimentsSerializer.serialize([
            record(id: "a:b;c%d", variant: "x:y;z%w", endedAt: end),
            record(.featureFlag, id: "plain", variant: nil),
            record(.featureFlag, id: "%%%", variant: ";;;")
        ])

        XCTAssertEqual(
            value,
            "e:a%3Ab%3Bc%25d:x%3Ay%3Bz%25w:1717459200000:1717462800000"
                + ";f:plain::1717459200000"
                + ";f:%25%25%25:%3B%3B%3B:1717459200000"
        )
    }

    // MARK: - Timestamps

    func test_encode_timestampsAreBareEpochMilliseconds() {
        let value = record(id: "a", variant: nil, startedAt: Date(timeIntervalSince1970: 1.5)).encoded
        XCTAssertEqual(value, "e:a::1500")
    }

    // MARK: - Cached encoding

    /// A record encodes itself on creation, so `serialize` has nothing left to build.
    func test_record_isEncodedOnCreation() {
        XCTAssertEqual(record(id: "abc1", variant: "A").encoded, "e:abc1:A:1717459200000")
        XCTAssertEqual(record(id: "abc1", variant: "A", endedAt: end).encoded, "e:abc1:A:1717459200000:1717462800000")
    }

    /// Ending a record is the one thing that changes its encoded form, and it must refresh the cache.
    func test_end_refreshesEncodedValue() {
        var subject = record(id: "abc1", variant: "A")
        XCTAssertEqual(subject.encoded, "e:abc1:A:1717459200000")

        subject.end(at: end)

        XCTAssertEqual(subject.endedAt, end)
        XCTAssertEqual(subject.encoded, "e:abc1:A:1717459200000:1717462800000")
        XCTAssertEqual(ExperimentsSerializer.serialize([subject]), "e:abc1:A:1717459200000:1717462800000")
    }

    /// Ending in place must match having been created ended, so the cache cannot drift from `init`.
    func test_end_matchesRecordCreatedAlreadyEnded() {
        var ended = record(id: "a:b", variant: "x;y")
        ended.end(at: end)

        XCTAssertEqual(ended.encoded, record(id: "a:b", variant: "x;y", endedAt: end).encoded)
    }
}
