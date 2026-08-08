import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    func testSingleWriterLegacyMergeAddsMissingRecordingAndEvidenceWithoutFakeAudioDuration() {
        let entries = [
            SuperDictateLegacyHistoryEntry(
                text: "Alpha project decision",
                transcriptionDurationSeconds: 1.25
            )
        ]

        let result = SuperDictateLegacyLibraryMerger.merge(
            entries,
            into: SuperDictateLibraryArchive()
        )

        XCTAssertTrue(result.changed)
        XCTAssertEqual(result.addedRecordingCount, 1)
        XCTAssertEqual(result.addedDocumentCount, 1)
        XCTAssertEqual(result.repairedRecordingMetadataCount, 0)
        XCTAssertEqual(result.archive.recordings.first?.transcript, "Alpha project decision")
        XCTAssertNil(result.archive.recordings.first?.durationSeconds)
        XCTAssertNil(result.archive.recordings.first?.createdAt)
        XCTAssertEqual(
            result.archive.memoryDocuments.first?.recordingID,
            result.archive.recordings.first?.id
        )
    }

    func testSingleWriterMergePreservesRealRuntimeIdentityAndAudioDuration() throws {
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 123)
        let result = SuperDictateLegacyLibraryMerger.merge(
            [
                SuperDictateLegacyHistoryEntry(
                    text: "New metadata row",
                    transcriptionDurationSeconds: 0.4,
                    recordingID: id,
                    createdAt: createdAt,
                    sourceAudioDurationSeconds: 8.75
                )
            ],
            into: SuperDictateLibraryArchive()
        )

        let recording = try XCTUnwrap(result.archive.recordings.first)
        XCTAssertEqual(recording.id, id)
        XCTAssertEqual(recording.createdAt, createdAt)
        XCTAssertEqual(recording.durationSeconds, 8.75)
        XCTAssertEqual(result.repairedRecordingMetadataCount, 0)
    }

    func testSingleWriterLegacyMergeIsIdempotent() {
        let entries = [
            SuperDictateLegacyHistoryEntry(text: "Repeated history", transcriptionDurationSeconds: nil)
        ]
        let first = SuperDictateLegacyLibraryMerger.merge(
            entries,
            into: SuperDictateLibraryArchive()
        )
        let second = SuperDictateLegacyLibraryMerger.merge(entries, into: first.archive)

        XCTAssertFalse(second.changed)
        XCTAssertEqual(second.archive, first.archive)
    }

    func testSingleWriterRepairsPreV2LegacyASRDurationPollution() {
        let text = "Old polluted row"
        let legacyID = SuperDictateLegacyHistoryMigrator.stableRecordingID(
            text: text,
            occurrence: 0
        )
        let polluted = SuperDictateRecording(
            id: legacyID,
            title: text,
            transcript: text,
            createdAt: nil,
            durationSeconds: 1.37
        )
        let archive = SuperDictateLibraryArchive(
            recordings: [polluted],
            memoryDocuments: [SuperDictateMemoryDocument(recording: polluted)]
        )

        let result = SuperDictateLegacyLibraryMerger.merge(
            [SuperDictateLegacyHistoryEntry(text: text, transcriptionDurationSeconds: 1.37)],
            into: archive
        )

        XCTAssertTrue(result.changed)
        XCTAssertEqual(result.repairedRecordingMetadataCount, 1)
        XCTAssertNil(result.archive.recordings.first?.durationSeconds)
        XCTAssertEqual(result.archive.recordings.first?.id, legacyID)
    }

    func testLegacyRepairDoesNotTouchRuntimeUUIDOrEnrichedLegacyDate() {
        let text = "Do not repair"
        let explicit = SuperDictateRecording(
            id: UUID(),
            title: text,
            transcript: text,
            createdAt: Date(timeIntervalSince1970: 10),
            durationSeconds: 4.5
        )
        let legacyID = SuperDictateLegacyHistoryMigrator.stableRecordingID(
            text: "Enriched legacy",
            occurrence: 0
        )
        let enrichedLegacy = SuperDictateRecording(
            id: legacyID,
            title: "Enriched legacy",
            transcript: "Enriched legacy",
            createdAt: Date(timeIntervalSince1970: 20),
            durationSeconds: 7
        )
        let archive = SuperDictateLibraryArchive(
            recordings: [explicit, enrichedLegacy],
            memoryDocuments: [
                SuperDictateMemoryDocument(recording: explicit),
                SuperDictateMemoryDocument(recording: enrichedLegacy),
            ]
        )

        let repaired = SuperDictateLegacyLibraryMerger.repairLegacyDurationPollution(in: archive)

        XCTAssertEqual(repaired.repairedCount, 0)
        XCTAssertEqual(repaired.archive, archive)
    }

    func testSingleWriterLegacyMergeDoesNotOverwriteRicherDurableState() throws {
        let entries = [
            SuperDictateLegacyHistoryEntry(text: "Same source text", transcriptionDurationSeconds: 1)
        ]
        let migrated = SuperDictateLegacyHistoryMigrator.archive(from: entries)
        let id = try XCTUnwrap(migrated.recordings.first?.id)

        let durable = SuperDictateRecording(
            id: id,
            title: "Confirmed meeting title",
            transcript: "Same source text",
            summary: "Durable summary",
            createdAt: Date(timeIntervalSince1970: 42),
            durationSeconds: 9,
            people: ["Ada"],
            requiresAttention: false
        )
        let durableDocument = SuperDictateMemoryDocument(
            recordingID: id,
            title: durable.title,
            segments: [
                SuperDictateEvidenceSegment(
                    text: "Rich evidence span",
                    speaker: "Ada",
                    startMilliseconds: 500,
                    endMilliseconds: 1_500
                )
            ]
        )
        let archive = SuperDictateLibraryArchive(
            recordings: [durable],
            tasks: [],
            memoryDocuments: [durableDocument]
        )

        let result = SuperDictateLegacyLibraryMerger.merge(entries, into: archive)

        XCTAssertFalse(result.changed)
        XCTAssertEqual(result.archive, archive)
    }
}
