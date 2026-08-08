import CryptoKit
import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    private func commitV5CAF(_ payload: String) -> Data {
        var data = Data("caff".utf8)
        data.append(Data(payload.utf8))
        return data
    }

    private func commitV5SHA(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func testV5ChunkCommitWritesManifestAndSHACommittedJournal() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateChunkV5-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        let committer = SuperDictateMemoryAudioChunkCommitter(store: store)
        let temp = try await committer.temporaryChunkURL(
            recordingID: recordingID,
            source: .system,
            sequence: 0,
            chunkID: chunkID
        )
        let bytes = commitV5CAF("source")
        try bytes.write(to: temp)

        let descriptor = try await committer.commitChunk(
            recordingID: recordingID,
            source: .system,
            sequence: 0,
            chunkID: chunkID,
            temporaryURL: temp,
            sessionStartMilliseconds: 100,
            sessionEndMilliseconds: 1_100,
            sampleRate: 48_000,
            channelCount: 2
        )

        XCTAssertEqual(descriptor.sha256, commitV5SHA(bytes))
        XCTAssertFalse(FileManager.default.fileExists(atPath: temp.path))
        let maybeManifest = try await store.loadManifest(recordingID: recordingID)
        let manifest = try XCTUnwrap(maybeManifest)
        XCTAssertEqual(manifest.chunks, [descriptor])

        let journal = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(journal.events.map(\.kind), [.chunkPrepared, .chunkCommitted])
        XCTAssertNil(journal.events.first?.sha256)
        XCTAssertEqual(journal.events.last?.sha256, descriptor.sha256)
    }

    func testV5InvalidCAFAndOversizeFailBeforeRename() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateChunkV5Preflight-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let committer = SuperDictateMemoryAudioChunkCommitter(store: store)
        let invalidID = UUID()
        let invalidTemp = try await committer.temporaryChunkURL(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: invalidID
        )
        try Data("not-caf".utf8).write(to: invalidTemp)
        do {
            _ = try await committer.commitChunk(
                recordingID: recordingID,
                source: .microphone,
                sequence: 0,
                chunkID: invalidID,
                temporaryURL: invalidTemp,
                sessionStartMilliseconds: 0,
                sessionEndMilliseconds: 100,
                sampleRate: 48_000,
                channelCount: 1
            )
            XCTFail("invalid CAF must fail before rename")
        } catch {
            XCTAssertEqual(error as? SuperDictateMemoryChunkCommitError, .invalidContainer)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: invalidTemp.path))

        let smallCommitter = SuperDictateMemoryAudioChunkCommitter(
            store: store,
            policy: SuperDictateMemoryChunkPolicy(maximumChunkBytes: 8)
        )
        let oversizedID = UUID()
        let oversizedTemp = try await smallCommitter.temporaryChunkURL(
            recordingID: recordingID,
            source: .system,
            sequence: 0,
            chunkID: oversizedID
        )
        let oversized = commitV5CAF("payload-too-large")
        try oversized.write(to: oversizedTemp)
        do {
            _ = try await smallCommitter.commitChunk(
                recordingID: recordingID,
                source: .system,
                sequence: 0,
                chunkID: oversizedID,
                temporaryURL: oversizedTemp,
                sessionStartMilliseconds: 0,
                sessionEndMilliseconds: 100,
                sampleRate: 48_000,
                channelCount: 2
            )
            XCTFail("oversized chunk must fail before rename")
        } catch {
            XCTAssertEqual(
                error as? SuperDictateMemoryChunkCommitError,
                .fileTooLarge(Int64(oversized.count), 8)
            )
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: oversizedTemp.path))
    }

    func testV5PostRenameManifestFailurePreservesPreparedOrphan() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateChunkV5Orphan-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        let committer = SuperDictateMemoryAudioChunkCommitter(store: store)

        let firstID = UUID()
        let firstTemp = try await committer.temporaryChunkURL(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: firstID
        )
        try commitV5CAF("first").write(to: firstTemp)
        _ = try await committer.commitChunk(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: firstID,
            temporaryURL: firstTemp,
            sessionStartMilliseconds: 0,
            sessionEndMilliseconds: 100,
            sampleRate: 48_000,
            channelCount: 1
        )

        let orphanID = UUID()
        let orphanTemp = try await committer.temporaryChunkURL(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: orphanID
        )
        try commitV5CAF("orphan").write(to: orphanTemp)
        do {
            _ = try await committer.commitChunk(
                recordingID: recordingID,
                source: .microphone,
                sequence: 0,
                chunkID: orphanID,
                temporaryURL: orphanTemp,
                sessionStartMilliseconds: 100,
                sessionEndMilliseconds: 200,
                sampleRate: 48_000,
                channelCount: 1
            )
            XCTFail("duplicate sequence should require recovery after rename")
        } catch {
            XCTAssertEqual(
                error as? SuperDictateMemoryChunkCommitError,
                .recoveryRequired(recordingID: recordingID, chunkID: orphanID)
            )
        }

        let finalURL = orphanTemp.deletingPathExtension()
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalURL.path))
        let journal = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(journal.latestEventByChunkID[orphanID]?.kind, .chunkPrepared)
        XCTAssertNil(journal.latestEventByChunkID[orphanID]?.sha256)
    }
}
