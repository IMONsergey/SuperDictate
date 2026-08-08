import Foundation
import XCTest
@testable import SuperDictateCore

final class LibraryReconciliationV2Tests: XCTestCase {
    func testBoundedLiveHistoryCannotDeleteDurableRecordings() {
        let oldDurable = SuperDictateRecording(
            title: "Older durable recording",
            transcript: "still belongs in Library",
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let recent = SuperDictateRecording(
            title: "Recent live recording",
            transcript: "visible in bounded cache",
            createdAt: Date(timeIntervalSince1970: 20)
        )
        let archive = SuperDictateLibraryArchive(
            recordings: [oldDurable, recent],
            tasks: [],
            memoryDocuments: [
                SuperDictateMemoryDocument(recording: oldDurable),
                SuperDictateMemoryDocument(recording: recent),
            ]
        )
        let live = SuperDictateProductSnapshot(recordings: [recent])

        let result = SuperDictateLibraryReconciler.reconcile(
            archive: archive,
            liveSnapshot: live
        )

        XCTAssertEqual(Set(result.archive.recordings.map(\.id)), Set([oldDurable.id, recent.id]))
        XCTAssertEqual(Set(result.snapshot.recordings.map(\.id)), Set([oldDurable.id, recent.id]))
        XCTAssertFalse(result.archiveChanged)
    }

    func testNewLiveRecordingIsAddedWithEvidenceDocument() {
        let liveRecording = SuperDictateRecording(
            title: "New dictation",
            transcript: "Ship the native Library integration"
        )
        let live = SuperDictateProductSnapshot(recordings: [liveRecording])

        let result = SuperDictateLibraryReconciler.reconcile(
            archive: SuperDictateLibraryArchive(),
            liveSnapshot: live
        )

        XCTAssertTrue(result.archiveChanged)
        XCTAssertEqual(result.addedRecordingCount, 1)
        XCTAssertEqual(result.addedDocumentCount, 1)
        XCTAssertEqual(result.archive.recordings.map(\.id), [liveRecording.id])
        XCTAssertEqual(result.archive.memoryDocuments.map(\.recordingID), [liveRecording.id])
    }

    func testDurableMetadataWinsWhileLiveAttentionOverlaysSnapshotOnly() throws {
        let id = UUID()
        let durable = SuperDictateRecording(
            id: id,
            title: "Confirmed title",
            transcript: "Durable transcript",
            summary: "Durable summary",
            createdAt: Date(timeIntervalSince1970: 42),
            durationSeconds: 12,
            people: ["Ada"],
            requiresAttention: false
        )
        let live = SuperDictateRecording(
            id: id,
            title: "legacy transcript prefix title",
            transcript: "Durable transcript",
            summary: nil,
            createdAt: nil,
            durationSeconds: nil,
            people: [],
            requiresAttention: true
        )
        let archive = SuperDictateLibraryArchive(
            recordings: [durable],
            tasks: [],
            memoryDocuments: [SuperDictateMemoryDocument(recording: durable)]
        )

        let result = SuperDictateLibraryReconciler.reconcile(
            archive: archive,
            liveSnapshot: SuperDictateProductSnapshot(
                status: .needsAttention,
                recordings: [live],
                issueMessage: "Microphone permission required"
            )
        )

        XCTAssertFalse(result.archiveChanged)
        XCTAssertEqual(result.archive.recordings, [durable])
        let visible = try XCTUnwrap(result.snapshot.recordings.first)
        XCTAssertEqual(visible.title, "Confirmed title")
        XCTAssertEqual(visible.summary, "Durable summary")
        XCTAssertEqual(visible.createdAt, durable.createdAt)
        XCTAssertEqual(visible.durationSeconds, 12)
        XCTAssertEqual(visible.people, ["Ada"])
        XCTAssertTrue(visible.requiresAttention)
        XCTAssertEqual(result.snapshot.status, .needsAttention)
        XCTAssertEqual(result.snapshot.issueMessage, "Microphone permission required")
        XCTAssertFalse(result.archive.recordings[0].requiresAttention)
    }

    func testDurableTasksRemainAvailableWhenLiveSnapshotHasNone() {
        let task = SuperDictateTask(title: "Schedule follow-up")
        let archive = SuperDictateLibraryArchive(
            recordings: [],
            tasks: [task],
            memoryDocuments: []
        )

        let result = SuperDictateLibraryReconciler.reconcile(
            archive: archive,
            liveSnapshot: SuperDictateProductSnapshot(tasks: [])
        )

        XCTAssertEqual(result.snapshot.tasks, [task])
        XCTAssertEqual(result.archive.tasks, [task])
    }
}
