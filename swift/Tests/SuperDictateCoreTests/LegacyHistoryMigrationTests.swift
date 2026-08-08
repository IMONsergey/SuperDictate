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

    func testDuplicateLegacyRowsReceiveDistinctStableIdentities() {
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

    func testLegacyASRDurationIsNotPresentedAsRecordingDuration() throws {
        let migrated = try XCTUnwrap(
            SuperDictateLegacyHistoryMigrator.recordings(
                from: [
                    SuperDictateLegacyHistoryEntry(
                        text: "Timed ASR transcript",
                        transcriptionDurationSeconds: 2.75
                    ),
                ]
            ).first
        )

        XCTAssertNil(migrated.createdAt)
        XCTAssertNil(migrated.durationSeconds)
    }

    func testRealRuntimeMetadataSurvivesProjection() throws {
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let migrated = try XCTUnwrap(
            SuperDictateLegacyHistoryMigrator.recordings(
                from: [
                    SuperDictateLegacyHistoryEntry(
                        text: "Metadata rich transcript",
                        transcriptionDurationSeconds: 0.8,
                        recordingID: id,
                        createdAt: createdAt,
                        sourceAudioDurationSeconds: 12.5
                    ),
                ]
            ).first
        )

        XCTAssertEqual(migrated.id, id)
        XCTAssertEqual(migrated.createdAt, createdAt)
        XCTAssertEqual(migrated.durationSeconds, 12.5)
    }

    func testExplicitIDRowsDoNotRenumberLegacyDuplicateFallbackIDs() {
        let legacyOnly = SuperDictateLegacyHistoryMigrator.recordings(
            from: [
                SuperDictateLegacyHistoryEntry(text: "Same words"),
                SuperDictateLegacyHistoryEntry(text: "Same words"),
            ]
        )
        let mixed = SuperDictateLegacyHistoryMigrator.recordings(
            from: [
                SuperDictateLegacyHistoryEntry(text: "Same words", recordingID: UUID()),
                SuperDictateLegacyHistoryEntry(text: "Same words"),
                SuperDictateLegacyHistoryEntry(text: "Same words"),
            ]
        )

        XCTAssertEqual(Array(mixed.dropFirst()).map(\.id), legacyOnly.map(\.id))
    }

    func testInvalidDurationsNormalizeToUnknown() {
        let entries = [
            SuperDictateLegacyHistoryEntry(
                text: "Negative",
                transcriptionDurationSeconds: -1,
                sourceAudioDurationSeconds: -2
            ),
            SuperDictateLegacyHistoryEntry(
                text: "Infinite",
                transcriptionDurationSeconds: .infinity,
                sourceAudioDurationSeconds: .infinity
            ),
        ]
        XCTAssertNil(entries[0].transcriptionDurationSeconds)
        XCTAssertNil(entries[0].sourceAudioDurationSeconds)
        XCTAssertNil(entries[1].transcriptionDurationSeconds)
        XCTAssertNil(entries[1].sourceAudioDurationSeconds)

        let migrated = SuperDictateLegacyHistoryMigrator.recordings(from: entries)
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
