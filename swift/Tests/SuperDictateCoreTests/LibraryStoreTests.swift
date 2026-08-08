import Foundation
import XCTest
@testable import SuperDictateCore

final class LibraryStoreTests: XCTestCase {
    private func temporaryRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("superdictate-library-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func recording(
        id: UUID = UUID(),
        title: String = "Recording",
        createdAt: Date? = nil
    ) -> SuperDictateRecording {
        SuperDictateRecording(
            id: id,
            title: title,
            transcript: "Private transcript for \(title)",
            createdAt: createdAt,
            people: ["Alice"]
        )
    }

    func testMissingIndexLoadsEmpty() async throws {
        let store = try JSONSuperDictateLibraryStore(rootDirectory: temporaryRoot())
        let archive = try await store.load()

        XCTAssertTrue(archive.recordings.isEmpty)
        XCTAssertTrue(archive.tasks.isEmpty)
        XCTAssertTrue(archive.memoryDocuments.isEmpty)
    }

    func testRoundTripPreservesUnknownDatesAndEvidence() async throws {
        let store = try JSONSuperDictateLibraryStore(rootDirectory: temporaryRoot())
        let legacy = recording(title: "Legacy", createdAt: nil)
        let known = recording(
            title: "Known",
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let archive = SuperDictateLibraryArchive(
            recordings: [legacy, known],
            memoryDocuments: [
                SuperDictateMemoryDocument(recording: legacy),
                SuperDictateMemoryDocument(recording: known),
            ]
        )

        try await store.save(archive)
        let loaded = try await store.load()

        XCTAssertEqual(loaded, archive)
        XCTAssertNil(loaded.recordings.first { $0.id == legacy.id }?.createdAt)
        XCTAssertNil(
            loaded.memoryDocuments.first { $0.recordingID == legacy.id }?.createdAt
        )
    }

    func testRecordingAndEvidenceUpsertKeepStableIdentity() async throws {
        let id = UUID()
        let store = try JSONSuperDictateLibraryStore(rootDirectory: temporaryRoot())
        let first = recording(id: id, title: "First")
        let updated = recording(
            id: id,
            title: "Updated",
            createdAt: Date(timeIntervalSince1970: 200)
        )

        try await store.upsertRecording(
            first,
            memoryDocument: SuperDictateMemoryDocument(recording: first)
        )
        try await store.upsertRecording(
            updated,
            memoryDocument: SuperDictateMemoryDocument(recording: updated)
        )
        let archive = try await store.load()

        XCTAssertEqual(archive.recordings.count, 1)
        XCTAssertEqual(archive.recordings.first?.title, "Updated")
        XCTAssertEqual(archive.memoryDocuments.count, 1)
        XCTAssertEqual(archive.memoryDocuments.first?.title, "Updated")
    }

    func testMismatchedEvidenceIdentityIsRejected() async throws {
        let source = recording(title: "Source")
        let wrong = SuperDictateMemoryDocument(
            recordingID: UUID(),
            title: "Wrong",
            segments: [SuperDictateEvidenceSegment(text: "wrong")]
        )
        let store = try JSONSuperDictateLibraryStore(rootDirectory: temporaryRoot())

        do {
            try await store.upsertRecording(source, memoryDocument: wrong)
            XCTFail("Expected identity mismatch")
        } catch let error as SuperDictateLibraryStoreError {
            XCTAssertEqual(
                error,
                .memoryDocumentRecordingMismatch(
                    recordingID: source.id,
                    documentID: wrong.recordingID
                )
            )
        }
    }

    func testSourceBackedTaskMustReferenceIndexedRecording() async throws {
        let missingID = UUID()
        let task = SuperDictateTask(
            title: "Follow up",
            sourceRecordingID: missingID,
            sourceExcerpt: "We will follow up."
        )
        let store = try JSONSuperDictateLibraryStore(rootDirectory: temporaryRoot())

        do {
            try await store.upsertTask(task)
            XCTFail("Expected orphan task rejection")
        } catch let error as SuperDictateLibraryStoreError {
            XCTAssertEqual(
                error,
                .orphanTaskSource(taskID: task.id, recordingID: missingID)
            )
        }
    }

    func testRemovingRecordingCascadesOnlyInsideIndex() async throws {
        let removeID = UUID()
        let source = recording(id: removeID, title: "Remove")
        let keep = recording(title: "Keep")
        let sourcedTask = SuperDictateTask(
            title: "Source task",
            sourceRecordingID: removeID,
            sourceExcerpt: "source"
        )
        let manualTask = SuperDictateTask(title: "Manual task")
        let store = try JSONSuperDictateLibraryStore(rootDirectory: temporaryRoot())
        try await store.save(
            SuperDictateLibraryArchive(
                recordings: [source, keep],
                tasks: [sourcedTask, manualTask],
                memoryDocuments: [
                    SuperDictateMemoryDocument(recording: source),
                    SuperDictateMemoryDocument(recording: keep),
                ]
            )
        )

        try await store.removeRecordingFromIndex(removeID)
        let archive = try await store.load()

        XCTAssertEqual(archive.recordings.map(\.id), [keep.id])
        XCTAssertEqual(archive.memoryDocuments.map(\.recordingID), [keep.id])
        XCTAssertEqual(archive.tasks.map(\.id), [manualTask.id])
    }

    func testDuplicateAndOrphanArchiveEntriesAreRejected() async throws {
        let id = UUID()
        let source = recording(id: id)
        let duplicate = recording(id: id, title: "Duplicate")
        let orphanDocument = SuperDictateMemoryDocument(
            recordingID: UUID(),
            title: "Orphan",
            segments: [SuperDictateEvidenceSegment(text: "orphan")]
        )
        let store = try JSONSuperDictateLibraryStore(rootDirectory: temporaryRoot())

        do {
            try await store.save(
                SuperDictateLibraryArchive(recordings: [source, duplicate])
            )
            XCTFail("Expected duplicate recording rejection")
        } catch let error as SuperDictateLibraryStoreError {
            XCTAssertEqual(error, .duplicateRecording(id))
        }

        do {
            try await store.save(
                SuperDictateLibraryArchive(
                    recordings: [source],
                    memoryDocuments: [orphanDocument]
                )
            )
            XCTFail("Expected orphan memory rejection")
        } catch let error as SuperDictateLibraryStoreError {
            XCTAssertEqual(error, .orphanMemoryDocument(orphanDocument.recordingID))
        }
    }

    func testOversizedSparseIndexIsRejectedBeforeDecode() async throws {
        let store = try JSONSuperDictateLibraryStore(rootDirectory: temporaryRoot())
        let url = await store.storageURL()
        FileManager.default.createFile(atPath: url.path, contents: Data())
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(
            atOffset: UInt64(JSONSuperDictateLibraryStore.maximumFileBytes + 1)
        )
        try handle.close()

        do {
            _ = try await store.load()
            XCTFail("Expected oversized file rejection")
        } catch let error as SuperDictateLibraryStoreError {
            guard case .fileTooLarge(let actual, let limit) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertGreaterThan(actual, limit)
            XCTAssertEqual(limit, JSONSuperDictateLibraryStore.maximumFileBytes)
        }
    }

    func testLeafSymlinkIsRejectedWithoutTouchingTarget() async throws {
        let root = try temporaryRoot()
        let store = try JSONSuperDictateLibraryStore(rootDirectory: root)
        try await store.save(SuperDictateLibraryArchive())
        let indexURL = await store.storageURL()
        let targetURL = root.appendingPathComponent("target.json")
        let targetBytes = Data("target".utf8)
        try targetBytes.write(to: targetURL)
        try FileManager.default.removeItem(at: indexURL)
        try FileManager.default.createSymbolicLink(
            at: indexURL,
            withDestinationURL: targetURL
        )

        do {
            _ = try await store.load()
            XCTFail("Expected symlink read rejection")
        } catch let error as SuperDictateLibraryStoreError {
            XCTAssertEqual(error, .unsafeFileType)
        }

        do {
            try await store.save(SuperDictateLibraryArchive())
            XCTFail("Expected symlink write rejection")
        } catch let error as SuperDictateLibraryStoreError {
            XCTAssertEqual(error, .unsafeFileType)
        }
        XCTAssertEqual(try Data(contentsOf: targetURL), targetBytes)
    }

    func testHardLinkedIndexIsRejected() async throws {
        let root = try temporaryRoot()
        let store = try JSONSuperDictateLibraryStore(rootDirectory: root)
        try await store.save(SuperDictateLibraryArchive())
        let indexURL = await store.storageURL()
        let hardLinkURL = root.appendingPathComponent("linked-index.json")
        try FileManager.default.linkItem(at: indexURL, to: hardLinkURL)

        do {
            _ = try await store.load()
            XCTFail("Expected hard-link rejection")
        } catch let error as SuperDictateLibraryStoreError {
            XCTAssertEqual(error, .unsafeFileType)
        }
    }

    #if os(macOS)
    func testIndexUsesPrivatePOSIXPermissions() async throws {
        let store = try JSONSuperDictateLibraryStore(rootDirectory: temporaryRoot())
        try await store.save(SuperDictateLibraryArchive())
        let fileURL = await store.storageURL()
        let directoryURL = fileURL.deletingLastPathComponent()

        let fileMode = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: fileURL.path)[.posixPermissions]
                as? NSNumber
        ).intValue
        let directoryMode = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: directoryURL.path)[.posixPermissions]
                as? NSNumber
        ).intValue

        XCTAssertEqual(fileMode & 0o777, 0o600)
        XCTAssertEqual(directoryMode & 0o777, 0o700)
    }
    #endif
}
