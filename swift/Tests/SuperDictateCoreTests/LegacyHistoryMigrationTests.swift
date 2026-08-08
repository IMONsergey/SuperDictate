import Foundation
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

        XCTAssertEqual(
            SuperDictateLegacyHistoryMigrator.recordings(from: entries),
            SuperDictateLegacyHistoryMigrator.recordings(from: entries)
        )
    }

    func testIdentityMatchesMergedRuntimeBridgeAlgorithm() {
        let recording = SuperDictateLegacyHistoryMigrator.recordings(
            from: [SuperDictateLegacyHistoryEntry(text: "Legacy transcript")]
        ).first

        XCTAssertEqual(
            recording?.id.uuidString.lowercased(),
            "d20e7bd7-0989-b7b5-cb10-a21942e5bb05"
        )
    }

    func testDuplicateRowsReceiveDistinctStableIdentities() {
        let entries = [
            SuperDictateLegacyHistoryEntry(text: "Same words"),
            SuperDictateLegacyHistoryEntry(text: "Same words"),
        ]
        let first = SuperDictateLegacyHistoryMigrator.recordings(from: entries)
        let second = SuperDictateLegacyHistoryMigrator.recordings(from: entries)

        XCTAssertEqual(Set(first.map(\.id)).count, 2)
        XCTAssertEqual(first.map(\.id), second.map(\.id))
        XCTAssertEqual(
            first.map { $0.id.uuidString.lowercased() },
            [
                "a7bcff15-b35b-aa50-8845-569a8872a9c4",
                "12da71d7-547f-12b6-dc18-dc958c31870f",
            ]
        )
    }

    func testUnknownChronologyStaysUnknownWhileKnownTimingSurvives() throws {
        let migrated = try XCTUnwrap(
            SuperDictateLegacyHistoryMigrator.recordings(
                from: [
                    SuperDictateLegacyHistoryEntry(
                        text: "Timed transcript",
                        transcriptionDurationSeconds: 2.75
                    ),
                ]
            ).first
        )

        XCTAssertNil(migrated.createdAt)
        XCTAssertEqual(migrated.durationSeconds, 2.75)
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

        XCTAssertNil(migrated[0].durationSeconds)
        XCTAssertNil(migrated[1].durationSeconds)
    }

    func testOuterWhitespaceUsesSameIdentityAsRuntimeBridgeNormalization() {
        let clean = SuperDictateLegacyHistoryMigrator.recordings(
            from: [SuperDictateLegacyHistoryEntry(text: "Same transcript")]
        )
        let padded = SuperDictateLegacyHistoryMigrator.recordings(
            from: [SuperDictateLegacyHistoryEntry(text: "  Same transcript\n")]
        )

        XCTAssertEqual(clean.first?.id, padded.first?.id)
        XCTAssertEqual(padded.first?.transcript, "Same transcript")
    }

    func testArchiveCreatesUntimedEvidenceForEveryLegacyRecording() {
        let archive = SuperDictateLegacyHistoryMigrator.archive(
            from: [
                SuperDictateLegacyHistoryEntry(text: "One"),
                SuperDictateLegacyHistoryEntry(text: "Two"),
            ]
        )

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
