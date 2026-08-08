import Foundation
import XCTest
@testable import SuperDictateCore

final class LegacyLibraryMergeTests: XCTestCase {
    func testMergeAddsMissingLegacyRecordingAndEvidence() {
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
        XCTAssertEqual(result.archive.recordings.count, 1)
        XCTAssertEqual(result.archive.memoryDocuments.count, 1)
        XCTAssertEqual(result.archive.recordings.first?.transcript, "Alpha project decision")
        XCTAssertEqual(result.archive.recordings.first?.durationSeconds, 1.25)
        XCTAssertNil(result.archive.recordings.first?.createdAt)
        XCTAssertEqual(
            result.archive.memoryDocuments.first?.recordingID,
            result.archive.recordings.first?.id
        )
    }

    func testMergeIsIdempotent() {
        let entries = [
            SuperDictateLegacyHistoryEntry(text: "Repeated history", transcriptionDurationSeconds: nil)
        ]
        let first = SuperDictateLegacyLibraryMerger.merge(
            entries,
            into: SuperDictateLibraryArchive()
        )
        let second = SuperDictateLegacyLibraryMerger.merge(entries, into: first.archive)

        XCTAssertFalse(second.changed)
        XCTAssertEqual(second.addedRecordingCount, 0)
        XCTAssertEqual(second.addedDocumentCount, 0)
        XCTAssertEqual(second.archive, first.archive)
    }

    func testLegacyMergeDoesNotOverwriteRicherDurableRecording() throws {
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
                SuperDictateMemorySegment(
                    text: "Rich evidence span",
                    startMilliseconds: 500,
                    endMilliseconds: 1_500,
                    speaker: "Ada"
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
        XCTAssertEqual(result.archive.recordings, [durable])
        XCTAssertEqual(result.archive.memoryDocuments, [durableDocument])
        XCTAssertEqual(result.archive.recordings.first?.summary, "Durable summary")
        XCTAssertEqual(result.archive.recordings.first?.people, ["Ada"])
        XCTAssertEqual(result.archive.memoryDocuments.first?.segments.first?.speaker, "Ada")
    }
}
