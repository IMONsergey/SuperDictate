import Foundation
import XCTest
@testable import SuperDictateCore

final class LibraryReconciliationTests: XCTestCase {
    func testRecentHistoryAbsenceDoesNotDeleteDurableRecording() {
        let recent = SuperDictateRecording(
            id: UUID(),
            title: "Recent",
            transcript: "recent"
        )
        let older = SuperDictateRecording(
            id: UUID(),
            title: "Older durable",
            transcript: "older"
        )
        let durable = SuperDictateLibraryArchive(
            recordings: [recent, older],
            memoryDocuments: [
                SuperDictateMemoryDocument(recording: recent),
                SuperDictateMemoryDocument(recording: older),
            ]
        )
        let live = SuperDictateProductSnapshot(recordings: [recent])

        let result = SuperDictateLibraryReconciler.reconcile(
            liveSnapshot: live,
            durableArchive: durable
        )

        XCTAssertEqual(result.archive.recordings.map(\.id), [recent.id, older.id])
        XCTAssertEqual(result.snapshot.recordings.map(\.id), [recent.id, older.id])
    }

    func testDurableMetadataWinsOverLossyLegacyProjection() {
        let id = UUID()
        let live = SuperDictateRecording(
            id: id,
            title: "Legacy transcript title",
            transcript: "legacy text",
            durationSeconds: 2,
            requiresAttention: true
        )
        let durable = SuperDictateRecording(
            id: id,
            title: "Client Discovery",
            transcript: "edited durable text",
            summary: "Durable summary",
            createdAt: Date(timeIntervalSince1970: 50),
            durationSeconds: 7,
            people: ["Alice"],
            requiresAttention: false
        )

        let result = SuperDictateLibraryReconciler.reconcile(
            liveSnapshot: SuperDictateProductSnapshot(recordings: [live]),
            durableArchive: SuperDictateLibraryArchive(
                recordings: [durable],
                memoryDocuments: [SuperDictateMemoryDocument(recording: durable)]
            )
        )
        let merged = result.archive.recordings[0]

        XCTAssertEqual(merged.title, "Client Discovery")
        XCTAssertEqual(merged.transcript, "edited durable text")
        XCTAssertEqual(merged.summary, "Durable summary")
        XCTAssertEqual(merged.people, ["Alice"])
        XCTAssertEqual(merged.durationSeconds, 7)
        XCTAssertEqual(merged.createdAt, Date(timeIntervalSince1970: 50))
        XCTAssertTrue(merged.requiresAttention)
    }

    func testRichEvidenceIsNeverDowngradedToUntimedFallback() {
        let id = UUID()
        let recording = SuperDictateRecording(
            id: id,
            title: "Meeting",
            transcript: "full transcript"
        )
        let richDocument = SuperDictateMemoryDocument(
            recordingID: id,
            title: "Meeting",
            segments: [
                SuperDictateEvidenceSegment(
                    text: "Decision one",
                    speaker: "Alice",
                    startMilliseconds: 1_000,
                    endMilliseconds: 2_000
                ),
                SuperDictateEvidenceSegment(
                    text: "Decision two",
                    speaker: "Bob",
                    startMilliseconds: 2_000,
                    endMilliseconds: 3_000
                ),
            ]
        )

        let result = SuperDictateLibraryReconciler.reconcile(
            liveSnapshot: SuperDictateProductSnapshot(recordings: [recording]),
            durableArchive: SuperDictateLibraryArchive(
                recordings: [recording],
                memoryDocuments: [richDocument]
            )
        )

        XCTAssertEqual(result.archive.memoryDocuments, [richDocument])
        XCTAssertTrue(result.archive.memoryDocuments[0].segments.allSatisfy(\.hasTimestamp))
    }

    func testStatusOnlyRefreshChangesSnapshotNotDurableContent() {
        let recording = SuperDictateRecording(
            id: UUID(),
            title: "Stable",
            transcript: "stable"
        )
        let archive = SuperDictateLibraryArchive(
            recordings: [recording],
            memoryDocuments: [SuperDictateMemoryDocument(recording: recording)]
        )

        let result = SuperDictateLibraryReconciler.reconcile(
            liveSnapshot: SuperDictateProductSnapshot(
                status: .transcribing,
                recordings: [recording]
            ),
            durableArchive: archive
        )

        XCTAssertEqual(result.archive, archive)
        XCTAssertEqual(result.snapshot.status, .transcribing)
    }

    func testLiveTaskUpdatesDurableTaskAndAppendsNewTask() {
        let existingID = UUID()
        let durableTask = SuperDictateTask(
            id: existingID,
            title: "Old task",
            isCompleted: false
        )
        let liveUpdated = SuperDictateTask(
            id: existingID,
            title: "Updated task",
            isCompleted: true
        )
        let liveNew = SuperDictateTask(title: "New task")

        let result = SuperDictateLibraryReconciler.reconcile(
            liveSnapshot: SuperDictateProductSnapshot(
                tasks: [liveUpdated, liveNew]
            ),
            durableArchive: SuperDictateLibraryArchive(tasks: [durableTask])
        )

        XCTAssertEqual(result.archive.tasks.count, 2)
        XCTAssertEqual(result.archive.tasks[0], liveUpdated)
        XCTAssertEqual(result.archive.tasks[1], liveNew)
    }

    func testNewLiveRecordingIsPlacedBeforeOlderDurableUnknownDateRows() {
        let new = SuperDictateRecording(
            id: UUID(),
            title: "New recent row",
            transcript: "new"
        )
        let old = SuperDictateRecording(
            id: UUID(),
            title: "Old durable row",
            transcript: "old"
        )

        let result = SuperDictateLibraryReconciler.reconcile(
            liveSnapshot: SuperDictateProductSnapshot(recordings: [new]),
            durableArchive: SuperDictateLibraryArchive(
                recordings: [old],
                memoryDocuments: [SuperDictateMemoryDocument(recording: old)]
            )
        )

        XCTAssertEqual(result.archive.recordings.map(\.id), [new.id, old.id])
    }
}
