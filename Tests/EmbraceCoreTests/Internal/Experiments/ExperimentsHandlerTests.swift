//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceConfiguration
import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceStorageInternal

final class ExperimentsHandlerTests: XCTestCase {

    var storage: EmbraceStorage!
    var logger: MockLogger!
    var notificationCenter: NotificationCenter!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
        logger = MockLogger()
        notificationCenter = NotificationCenter()
    }

    override func tearDownWithError() throws {
        storage.coreData.destroy()
        storage = nil
    }

    private func handler(limits: ExperimentsLimits = ExperimentsLimits()) -> ExperimentsHandler {
        ExperimentsHandler(
            storage: storage,
            experimentsLimits: limits,
            configNotificationCenter: notificationCenter,
            logger: logger
        )
    }

    /// Splits an encoded value into its records, each as its raw `kind:id:variant:start[:end]` fields.
    ///
    /// Not an inverse of the serializer: it just slices the strings these tests produce, whose ids and
    /// variants never contain an escaped separator.
    private func records(_ encoded: String?) -> [[String]] {
        guard let encoded = encoded, !encoded.isEmpty else {
            return []
        }
        return encoded.components(separatedBy: ";").map { $0.components(separatedBy: ":") }
    }

    /// Reads a timestamp field back as a `Date`.
    private func date(_ field: String) -> Date? {
        guard let milliseconds = Double(field) else {
            return nil
        }
        return Date(timeIntervalSince1970: milliseconds / 1000.0)
    }

    private func warnings() -> Int {
        logger.loggedMessages.filter { $0.level == .warning }.count
    }

    private func storedValue() -> String? {
        storage.fetchMetadata(
            key: SpanSemantics.keyExperiments,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.stringValue
        )?.value
    }

    // MARK: - Write once & identity

    func test_track_repeatedId_doesNotChangeVariantOrStartTime() {
        let handler = handler()
        let started = Date(timeIntervalSince1970: 1000)

        handler.trackExperiments([.init(id: "exp", variant: "A", startedAt: started)])
        let first = handler.encodedExperiments

        handler.trackExperiments([.init(id: "exp", variant: "B", startedAt: Date(timeIntervalSince1970: 9999))])

        XCTAssertEqual(handler.encodedExperiments, first)
        XCTAssertEqual(handler.encodedExperiments, "e:exp:A:1000000")
    }

    func test_track_sameIdAsExperimentAndFlag_areIndependent() {
        let handler = handler()
        let started = Date(timeIntervalSince1970: 1000)

        handler.trackExperiments([.init(id: "dark-mode", variant: "A", startedAt: started)])
        handler.trackFeatureFlags([.init(id: "dark-mode", variant: "B", startedAt: started)])

        XCTAssertEqual(handler.encodedExperiments, "e:dark-mode:A:1000000;f:dark-mode:B:1000000")
    }

    func test_untrack_matchesOnKindAsWellAsId() {
        let handler = handler()
        let started = Date(timeIntervalSince1970: 1000)
        let ended = Date(timeIntervalSince1970: 2000)

        handler.trackExperiments([.init(id: "dark-mode", startedAt: started)])
        handler.trackFeatureFlags([.init(id: "dark-mode", startedAt: started)])

        handler.untrackFeatureFlags(ids: ["dark-mode"], endedAt: ended)

        // the flag is closed, the experiment is left open
        XCTAssertEqual(handler.encodedExperiments, "e:dark-mode::1000000;f:dark-mode::1000000:2000000")
    }

    func test_track_afterUntrack_doesNotReactivate() {
        let handler = handler()
        handler.trackExperiments([.init(id: "exp", startedAt: Date(timeIntervalSince1970: 1000))])
        handler.untrackExperiments(ids: ["exp"], endedAt: Date(timeIntervalSince1970: 2000))
        let ended = handler.encodedExperiments

        handler.trackExperiments([.init(id: "exp", variant: "new", startedAt: Date(timeIntervalSince1970: 3000))])

        XCTAssertEqual(handler.encodedExperiments, ended)
        XCTAssertEqual(handler.encodedExperiments, "e:exp::1000000:2000000")
    }

    func test_untrack_repeated_doesNotMoveEndTime() {
        let handler = handler()
        handler.trackExperiments([.init(id: "exp", startedAt: Date(timeIntervalSince1970: 1000))])
        handler.untrackExperiments(ids: ["exp"], endedAt: Date(timeIntervalSince1970: 2000))

        handler.untrackExperiments(ids: ["exp"], endedAt: Date(timeIntervalSince1970: 5000))

        XCTAssertEqual(handler.encodedExperiments, "e:exp::1000000:2000000")
    }

    func test_untrack_unknownId_isIgnored() {
        let handler = handler()
        handler.trackExperiments([.init(id: "exp", startedAt: Date(timeIntervalSince1970: 1000))])
        let before = handler.encodedExperiments

        handler.untrackExperiments(ids: ["nope"], endedAt: Date(timeIntervalSince1970: 2000))

        XCTAssertEqual(handler.encodedExperiments, before)
    }

    // MARK: - Timestamps

    func test_track_omittedStartedAt_usesCallTime() {
        let handler = handler()
        let before = Date()
        handler.trackExperiments([.init(id: "exp")])
        let after = Date()

        let parsed = records(handler.encodedExperiments)
        XCTAssertEqual(parsed.count, 1)

        let startedAt = try? XCTUnwrap(date(parsed[0][3]))
        XCTAssertNotNil(startedAt)
        XCTAssertGreaterThanOrEqual(startedAt!.timeIntervalSince1970, before.timeIntervalSince1970 - 0.001)
        XCTAssertLessThanOrEqual(startedAt!.timeIntervalSince1970, after.timeIntervalSince1970 + 0.001)
    }

    func test_untrack_omittedEndedAt_usesCallTime() {
        let handler = handler()
        handler.trackExperiments([.init(id: "exp", startedAt: Date(timeIntervalSince1970: 1000))])

        let before = Date()
        handler.untrackExperiments(ids: ["exp"])
        let after = Date()

        let parsed = records(handler.encodedExperiments)
        XCTAssertEqual(parsed.first?.count, 5, "the record should have gained an end time")

        let endedAt = try? XCTUnwrap(date(parsed[0][4]))
        XCTAssertNotNil(endedAt)
        XCTAssertGreaterThanOrEqual(endedAt!.timeIntervalSince1970, before.timeIntervalSince1970 - 0.001)
        XCTAssertLessThanOrEqual(endedAt!.timeIntervalSince1970, after.timeIntervalSince1970 + 0.001)
    }

    /// All entries in one call that omit their timestamp share the same capture time.
    func test_track_bulkWithoutTimestamps_sharesOneCaptureTime() {
        let handler = handler()
        handler.trackExperiments([.init(id: "a"), .init(id: "b"), .init(id: "c")])

        let parsed = records(handler.encodedExperiments)
        XCTAssertEqual(parsed.count, 3)
        XCTAssertEqual(parsed[0][3], parsed[1][3])
        XCTAssertEqual(parsed[1][3], parsed[2][3])
    }

    // MARK: - Normalization

    /// The spec's worked example: `" a:b "` is stored as `a:b`, measured as 3 characters, matched by
    /// `untrackExperiment("a:b")` and serialized as `a%3Ab`.
    func test_normalization_workedExample() {
        let handler = handler(limits: ExperimentsLimits(maxIdLength: 3))
        handler.trackExperiments([.init(id: " a:b ", startedAt: Date(timeIntervalSince1970: 1000))])

        // stored trimmed, measured as 3 chars (so it fits a limit of 3), serialized escaped
        XCTAssertEqual(handler.encodedExperiments, "e:a%3Ab::1000000")

        // and matched by the trimmed id
        handler.untrackExperiments(ids: ["a:b"], endedAt: Date(timeIntervalSince1970: 2000))
        XCTAssertEqual(handler.encodedExperiments, "e:a%3Ab::1000000:2000000")
    }

    func test_normalization_stripsTheSixAsciiWhitespaceCodePoints() {
        let handler = handler()
        let whitespace = "\u{09}\u{0A}\u{0B}\u{0C}\u{0D}\u{20}"

        handler.trackExperiments([
            .init(id: whitespace + "exp" + whitespace, variant: whitespace + "A" + whitespace, startedAt: Date(timeIntervalSince1970: 1000))
        ])

        XCTAssertEqual(handler.encodedExperiments, "e:exp:A:1000000")
    }

    /// Code points that look like whitespace but are not the six ASCII ones must survive.
    func test_normalization_keepsNonAsciiWhitespace() {
        let handler = handler()
        let scalars = ["\u{85}", "\u{1C}", "\u{1D}", "\u{1E}", "\u{1F}", "\u{A0}", "\u{3000}"]

        for scalar in scalars {
            handler.trackExperiments([.init(id: scalar + "id" + scalar, startedAt: Date(timeIntervalSince1970: 1000))])
        }

        let parsed = records(handler.encodedExperiments)
        XCTAssertEqual(parsed.count, scalars.count, "each padded id must stay distinct from the others")
        for record in parsed {
            XCTAssertNotEqual(record[1], "id", "the padding must survive trimming")
        }
    }

    func test_normalization_whitespaceOnlyId_dropsEntry() {
        let handler = handler()
        handler.trackExperiments([
            .init(id: "   ", startedAt: Date(timeIntervalSince1970: 1000)),
            .init(id: "kept", startedAt: Date(timeIntervalSince1970: 1000))
        ])

        XCTAssertEqual(handler.encodedExperiments, "e:kept::1000000")
    }

    func test_normalization_whitespaceOnlyVariant_keepsEntryWithoutVariant() {
        let handler = handler()
        handler.trackExperiments([.init(id: "exp", variant: "   ", startedAt: Date(timeIntervalSince1970: 1000))])

        XCTAssertEqual(handler.encodedExperiments, "e:exp::1000000")
    }

    func test_normalization_limitsApplyToStrippedValue() {
        let handler = handler(limits: ExperimentsLimits(maxIdLength: 5))
        let padded = "   " + String(repeating: "a", count: 5) + "   "

        handler.trackExperiments([.init(id: padded, startedAt: Date(timeIntervalSince1970: 1000))])

        XCTAssertEqual(handler.encodedExperiments, "e:aaaaa::1000000")
    }

    // MARK: - Limits

    func test_limits_idAtLimitAccepted_overLimitDropsWholeEntry() {
        let handler = handler(limits: ExperimentsLimits(maxIdLength: 4))

        handler.trackExperiments([
            .init(id: "abcd", startedAt: Date(timeIntervalSince1970: 1000)),
            .init(id: "abcde", startedAt: Date(timeIntervalSince1970: 1000))
        ])

        // the over-length id is absent entirely, never truncated
        XCTAssertEqual(handler.encodedExperiments, "e:abcd::1000000")
    }

    func test_limits_overLengthVariant_dropsWholeEntryNotJustTheVariant() {
        let handler = handler(limits: ExperimentsLimits(maxVariantLength: 2))

        handler.trackExperiments([.init(id: "exp", variant: "toolong", startedAt: Date(timeIntervalSince1970: 1000))])

        XCTAssertNil(handler.encodedExperiments)
    }

    func test_limits_recordCap() {
        let handler = handler(limits: ExperimentsLimits(maxCount: 2))

        handler.trackExperiments([
            .init(id: "a", startedAt: Date(timeIntervalSince1970: 1000)),
            .init(id: "b", startedAt: Date(timeIntervalSince1970: 1000)),
            .init(id: "c", startedAt: Date(timeIntervalSince1970: 1000))
        ])

        XCTAssertEqual(handler.encodedExperiments, "e:a::1000000;e:b::1000000")
    }

    /// At the cap, closing an existing record must still work even though it makes the value grow.
    func test_limits_atCap_untrackOfExistingRecordStillCloses() {
        let handler = handler(limits: ExperimentsLimits(maxCount: 1))
        handler.trackExperiments([.init(id: "a", startedAt: Date(timeIntervalSince1970: 1000))])

        handler.untrackExperiments(ids: ["a"], endedAt: Date(timeIntervalSince1970: 2000))

        XCTAssertEqual(handler.encodedExperiments, "e:a::1000000:2000000")
    }

    /// At the cap, a repeat track of an existing record is a silent no-op, not a refusal.
    func test_limits_atCap_repeatTrackOfExistingRecordIsSilent() {
        let handler = handler(limits: ExperimentsLimits(maxCount: 1))
        handler.trackExperiments([.init(id: "a", startedAt: Date(timeIntervalSince1970: 1000))])

        logger.reset()
        handler.trackExperiments([.init(id: "a", variant: "other")])
        handler.untrackExperiments(ids: ["a"], endedAt: Date(timeIntervalSince1970: 2000))

        XCTAssertEqual(warnings(), 0, "existing records must not emit cap telemetry")
    }

    func test_limits_genuineCapDrop_warns() {
        let handler = handler(limits: ExperimentsLimits(maxCount: 1))
        handler.trackExperiments([.init(id: "a")])

        logger.reset()
        handler.trackExperiments([.init(id: "b")])

        XCTAssertEqual(warnings(), 1)
    }

    // MARK: - Remote config updates

    func test_configUpdate_raisingLimits_letsNewRecordsThrough() {
        let handler = handler(limits: ExperimentsLimits(maxCount: 1))
        handler.trackExperiments([.init(id: "a", startedAt: Date(timeIntervalSince1970: 1000))])
        handler.trackExperiments([.init(id: "b", startedAt: Date(timeIntervalSince1970: 1000))])
        XCTAssertEqual(handler.encodedExperiments, "e:a::1000000")

        let config = MockEmbraceConfigurable(experimentsLimits: ExperimentsLimits(maxCount: 10))
        notificationCenter.post(name: .embraceConfigUpdated, object: config)

        handler.trackExperiments([.init(id: "b", startedAt: Date(timeIntervalSince1970: 1000))])
        XCTAssertEqual(handler.encodedExperiments, "e:a::1000000;e:b::1000000")
    }

    func test_configUpdate_loweringLimits_doesNotDropExistingRecords() {
        let handler = handler(limits: ExperimentsLimits(maxCount: 10))
        handler.trackExperiments([
            .init(id: "a", startedAt: Date(timeIntervalSince1970: 1000)),
            .init(id: "b", startedAt: Date(timeIntervalSince1970: 1000))
        ])
        let before = handler.encodedExperiments

        let config = MockEmbraceConfigurable(experimentsLimits: ExperimentsLimits(maxCount: 1))
        notificationCenter.post(name: .embraceConfigUpdated, object: config)

        XCTAssertEqual(handler.encodedExperiments, before)
    }

    func test_configUpdate_withUnexpectedObject_isIgnored() {
        let handler = handler(limits: ExperimentsLimits(maxCount: 1))
        notificationCenter.post(name: .embraceConfigUpdated, object: "not a config")

        handler.trackExperiments([
            .init(id: "a", startedAt: Date(timeIntervalSince1970: 1000)),
            .init(id: "b", startedAt: Date(timeIntervalSince1970: 1000))
        ])

        XCTAssertEqual(handler.encodedExperiments, "e:a::1000000", "limits should be unchanged")
    }

    // MARK: - Bulk semantics

    func test_bulk_andSingleEntry_produceIdenticalOutput() {
        let started = Date(timeIntervalSince1970: 1000)

        let bulkHandler = handler()
        bulkHandler.trackExperiments([
            .init(id: "a", variant: "A", startedAt: started),
            .init(id: "b", startedAt: started)
        ])

        let singleHandler = handler()
        singleHandler.trackExperiments([.init(id: "a", variant: "A", startedAt: started)])
        singleHandler.trackExperiments([.init(id: "b", startedAt: started)])

        XCTAssertEqual(bulkHandler.encodedExperiments, singleHandler.encodedExperiments)
    }

    func test_bulk_invalidEntriesDropWithoutStoppingTheRest() {
        let handler = handler(limits: ExperimentsLimits(maxIdLength: 3))

        handler.trackExperiments([
            .init(id: "ok1", startedAt: Date(timeIntervalSince1970: 1000)),
            .init(id: "", startedAt: Date(timeIntervalSince1970: 1000)),
            .init(id: "waytoolong", startedAt: Date(timeIntervalSince1970: 1000)),
            .init(id: "ok2", startedAt: Date(timeIntervalSince1970: 1000))
        ])

        XCTAssertEqual(handler.encodedExperiments, "e:ok1::1000000;e:ok2::1000000")
    }

    func test_bulk_duplicateIdsResolveFirstWins() {
        let handler = handler()

        handler.trackExperiments([
            .init(id: "dup", variant: "first", startedAt: Date(timeIntervalSince1970: 1000)),
            .init(id: "dup", variant: "second", startedAt: Date(timeIntervalSince1970: 2000))
        ])

        XCTAssertEqual(handler.encodedExperiments, "e:dup:first:1000000")
    }

    func test_emptyList_isANoOp() {
        let handler = handler()

        handler.trackExperiments([])
        handler.trackFeatureFlags([])
        handler.untrackExperiments(ids: [])

        XCTAssertNil(handler.encodedExperiments)
        wait(delay: .shortTimeout)
        XCTAssertNil(storedValue())
    }

    // MARK: - Persistence

    func test_persistence_writesRequiredProcessResource() throws {
        let handler = handler()
        handler.trackExperiments([.init(id: "exp", variant: "A", startedAt: Date(timeIntervalSince1970: 1000))])

        wait(delay: .shortTimeout)

        let metadata = try XCTUnwrap(
            storage.fetchMetadata(
                key: SpanSemantics.keyExperiments,
                type: .requiredResource,
                lifespan: .process,
                lifespanId: ProcessIdentifier.current.stringValue
            )
        )

        XCTAssertEqual(metadata.value, "e:exp:A:1000000")
        XCTAssertEqual(metadata.typeRaw, MetadataRecordType.requiredResource.rawValue)
        XCTAssertEqual(metadata.lifespanRaw, MetadataRecordLifespan.process.rawValue)
        XCTAssertEqual(metadata.lifespanId, ProcessIdentifier.current.stringValue)
    }

    /// The value is exempt from the standard 1024 character attribute limit. This fails if the write is
    /// ever routed back through `MetadataHandler`, which truncates.
    func test_persistence_valueOver1024CharactersIsNotTruncated() {
        let handler = handler()

        let entries = (0..<20).map {
            TrackedExperiment(
                id: "id-\($0)-" + String(repeating: "x", count: 100),
                startedAt: Date(timeIntervalSince1970: 1000)
            )
        }
        handler.trackExperiments(entries)

        wait(delay: .shortTimeout)

        let stored = storedValue()
        XCTAssertNotNil(stored)
        XCTAssertGreaterThan(stored!.count, 1024)
        XCTAssertEqual(stored, handler.encodedExperiments)
        XCTAssertFalse(stored!.hasSuffix("..."))
    }

    func test_persistence_nothingIsWrittenBeforeFirstSuccessfulTrack() {
        let handler = handler()

        handler.trackExperiments([.init(id: "  ")])
        wait(delay: .shortTimeout)

        XCTAssertNil(handler.encodedExperiments)
        XCTAssertNil(storedValue())
    }

    // MARK: - Concurrency

    func test_concurrentTrackAndUntrack_leavesConsistentValue() {
        let handler = handler(limits: ExperimentsLimits(maxCount: 5000))

        DispatchQueue.concurrentPerform(iterations: 100) { i in
            handler.trackExperiments([.init(id: "exp-\(i)", startedAt: Date(timeIntervalSince1970: 1000))])
            handler.untrackExperiments(ids: ["exp-\(i)"], endedAt: Date(timeIntervalSince1970: 2000))
        }

        let parsed = records(handler.encodedExperiments)

        XCTAssertEqual(parsed.count, 100)
        XCTAssertEqual(Set(parsed.map { $0[1] }).count, 100, "no duplicates")
        XCTAssertTrue(parsed.allSatisfy { $0.count == 5 }, "every record ended")
    }
}
