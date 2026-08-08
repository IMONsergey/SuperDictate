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

    func testRoundTripPreservesUnknownDatesInsteadOfInventingNow() async throws {
        let root = try temporaryRoot()
        let store = try JSONSuperDictateLibraryStore(rootDirectory: root)
        let unknownDate = recording(title: "Legacy", createdAt: nil)
        let knownDate = recording(
            title: "Known",
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let archive = SuperDictateLibraryArchive(
            recordings: [unknownDate, knownDate],
            memoryDocuments: [
                SuperDictateMemoryDocument(recording: unknownDate),
                SuperDictateMemoryDocument(recording: knownDate),
            ]
        )

        try await store.save(archive)
        let loaded = try await store.load()

        XCTAssertEqual(loaded, archive)
        XCTAssertNil(loaded.recordings.first { $0.id == unknownDate.id }?.createdAt)
        XCTAssertNil(
            loaded.memoryDocuments.first { $0.recordingID == unknownDate.id }?.createdAt
        )
    }

    func testRecordingAndEvidenceUpsertUseOneStableIdentity() async throws {
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
        let recording = recording(title: "Source")
        let wrongDocument = SuperDictateMemoryDocument(
            recordingID: UUID(),
            title: "Wrong",
            segments: [SuperDictateEvidenceSegment(text: "wrong")]
        )
        let store = try JSONSuperDictateLibraryStore(rootDirectory: temporaryRoot())

        do {
            try await store.upsertRecording(recording, memoryDocument: wrongDocument)
            XCTFail("Expected identity mismatch")
        } catch let error as SuperDictateLibraryStoreError {
            XCTAssertEqual(
                error,
                .memoryDocumentRecordingMismatch(
                    recordingID: recording.id,
                    documentID: wrongDocument.recordingID
                )
            )
        }
    }

    func testTaskSourceMustExistWhenTaskClaimsRecordingEvidence() async throws {
        let missingRecordingID = UUID()
        let task = SuperDictateTask(
            title: "Follow up",
            sourceRecordingID: missingRecordingID,
            sourceExcerpt: "We will follow up."
        )
        let store = try JSONSuperDictateLibraryStore(rootDirectory: temporaryRoot())

        do {
            try await store.upsertTask(task)
            XCTFail("Expected orphan source rejection")
        } catch let error as SuperDictateLibraryStoreError {
            XCTAssertEqual(
                error,
                .orphanTaskSource(
                    taskID: task.id,
                    recordingID: missingRecordingID
                )
            )
        }
    }

    func testRemovingRecordingCascadesOnlyInsideIndex() async throws {
        let id = UUID()
        let source = recording(id: id, title: "Delete projection")
        let keep = recording(title: "Keep")
        let sourcedTask = SuperDictateTask(
            title: "Source task",
            sourceRecordingID: id,
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

        try await store.removeRecordingFromIndex(id)
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
            XCTAssertEqual(
                error,
                .orphanMemoryDocument(orphanDocument.recordingID)
            )
        }
    }

    func testUnsupportedSchemaIsRejected() async throws {
        let store = try JSONSuperDictateLibraryStore(rootDirectory: temporaryRoot())
        try await store.save(SuperDictateLibraryArchive())
        let url = await store.storageURL()
        let data = try Data(contentsOf: url)
        var json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        json["schemaVersion"] = 999
        let invalid = try JSONSerialization.data(withJSONObject: json)
        try invalid.write(to: url, options: [.atomic])

        do {
            _ = try await store.load()
            XCTFail("Expected unsupported schema")
        } catch let error as SuperDictateLibraryStoreError {
            XCTAssertEqual(error, .unsupportedSchema(999))
        }
    }

    func testOversizedIndexIsRejectedBeforeDecode() async throws {
        let store = try JSONSuperDictateLibraryStore(rootDirectory: temporaryRoot())
        let url = await store.storageURL()
        try Data(
            repeating: 0x20,
            count: JSONSuperDictateLibraryStore.maximumFileBytes + 1
        ).write(to: url)

        do {
            _ = try await store.load()
            XCTFail("Expected oversized file")
        } catch let error as SuperDictateLibraryStoreError {
            guard case .fileTooLarge(let actual, let limit) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertGreaterThan(actual, limit)
            XCTAssertEqual(limit, JSONSuperDictateLibraryStore.maximumFileBytes)
        }
    }

    func testLeafSymlinkIsRejectedForReadAndWrite() async throws {
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
