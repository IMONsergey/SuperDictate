import XCTest
@testable import SuperDictateCore

final class LegacyHistoryMigrationTests: XCTestCase {
    func testMigrationIsDeterministicAcrossRuns() {
        let entries = [
            SuperDictateLegacyHistoryEntry(
                text: "First transcript",
                transcriptionDurationSeconds: 1.25
            ),
            SuperDictateLegacyHistoryEntry(text: "Second transcript"),
        ]

        let first = SuperDictateLegacyHistoryMigrator.recordings(from: entries)
        let second = SuperDictateLegacyHistoryMigrator.recordings(from: entries)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.map(\.id), second.map(\.id))
    }

    func testDuplicateRowsReceiveDistinctStableIdentities() {
        let entries = [
            SuperDictateLegacyHistoryEntry(text: "Same words"),
            SuperDictateLegacyHistoryEntry(text: "Same words"),
            SuperDictateLegacyHistoryEntry(text: "Same words"),
        ]

        let migrated = SuperDictateLegacyHistoryMigrator.recordings(from: entries)
        let repeated = SuperDictateLegacyHistoryMigrator.recordings(from: entries)

        XCTAssertEqual(Set(migrated.map(\.id)).count, 3)
        XCTAssertEqual(migrated.map(\.id), repeated.map(\.id))
    }

    func testUnknownChronologyStaysUnknown() {
        let migrated = SuperDictateLegacyHistoryMigrator.recordings(
            from: [SuperDictateLegacyHistoryEntry(text: "Legacy transcript")]
        )

        XCTAssertNil(migrated.first?.createdAt)
    }

    func testKnownLegacyDurationIsPreservedWithoutFabricatingCaptureDuration() {
        let migrated = SuperDictateLegacyHistoryMigrator.recordings(
            from: [
                SuperDictateLegacyHistoryEntry(
                    text: "Timed transcript",
                    transcriptionDurationSeconds: 2.75
                ),
            ]
        )

        XCTAssertEqual(migrated.first?.durationSeconds, 2.75)
    }

    func testInvalidDurationsNormalizeToUnknown() {
        let migrated = SuperDictateLegacyHistoryMigrator.recordings(
            from: [
                SuperDictateLegacyHistoryEntry(
                    text: "Negative",
                    transcriptionDurationSeconds: -1
                ),
                SuperDictateLegacyHistoryEntry(
                    text: "Infinite",
                    transcriptionDurationSeconds: .infinity
                ),
            ]
        )

        XCTAssertEqual(migrated.count, 2)
        XCTAssertNil(migrated[0].durationSeconds)
        XCTAssertNil(migrated[1].durationSeconds)
    }

    func testOuterWhitespaceDoesNotCreateDifferentLegacyIdentity() {
        let clean = SuperDictateLegacyHistoryMigrator.recordings(
            from: [SuperDictateLegacyHistoryEntry(text: "Same transcript")]
        )
        let padded = SuperDictateLegacyHistoryMigrator.recordings(
            from: [SuperDictateLegacyHistoryEntry(text: "  Same transcript\n")]
        )

        XCTAssertEqual(clean.first?.id, padded.first?.id)
        XCTAssertEqual(padded.first?.transcript, "Same transcript")
    }

    func testDurationParticipatesInIdentity() {
        let fast = SuperDictateLegacyHistoryMigrator.recordings(
            from: [
                SuperDictateLegacyHistoryEntry(
                    text: "Same transcript",
                    transcriptionDurationSeconds: 1
                ),
            ]
        )
        let slow = SuperDictateLegacyHistoryMigrator.recordings(
            from: [
                SuperDictateLegacyHistoryEntry(
                    text: "Same transcript",
                    transcriptionDurationSeconds: 2
                ),
            ]
        )

        XCTAssertNotEqual(fast.first?.id, slow.first?.id)
    }

    func testTitleIsReadableAndBounded() throws {
        let text = String(repeating: "word ", count: 40)
        let migrated = try XCTUnwrap(
            SuperDictateLegacyHistoryMigrator.recordings(
                from: [SuperDictateLegacyHistoryEntry(text: text)]
            ).first
        )

        XCTAssertLessThanOrEqual(migrated.title.count, 64)
        XCTAssertTrue(migrated.title.hasSuffix("…"))
        XCTAssertFalse(migrated.title.contains("\n"))
    }

    func testArchiveCreatesUntimedEvidenceForEveryMigratedRecording() {
        let archive = SuperDictateLegacyHistoryMigrator.archive(
            from: [
                SuperDictateLegacyHistoryEntry(text: "One"),
                SuperDictateLegacyHistoryEntry(text: "Two"),
            ]
        )

        XCTAssertEqual(archive.recordings.count, 2)
        XCTAssertEqual(archive.memoryDocuments.count, 2)
        XCTAssertEqual(
            Set(archive.recordings.map(\.id)),
            Set(archive.memoryDocuments.map(\.recordingID))
        )
        XCTAssertTrue(
            archive.memoryDocuments.allSatisfy { document in
                document.segments.count == 1 && !document.segments[0].hasTimestamp
            }
        )
    }
}
