import CryptoKit
import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    private func chunkV6CAF(_ payload: String) -> Data {
        var data = Data("caff".utf8)
        data.append(Data(payload.utf8))
        return data
    }

    private func chunkV6SHA(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func testMemoryChunkCommitV6FinalizesSourceAndPersistsChecksumBoundJournal() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateChunkV6-\(UUID().uuidString)", isDirectory: true)
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
        let bytes = chunkV6CAF("source")
        try bytes.write(to: temp)

        let descriptor = try await committer.commitChunk(
            recordingID: recordingID,
            source: .system,
            sequence: 0,
            chunkID: chunkID,
            temporaryURL: temp,
            sessionStartMilliseconds: 125,
            sessionEndMilliseconds: 1_125,
            sampleRate: 48_000,
            channelCount: 2
        )
        XCTAssertEqual(descriptor.sha256, chunkV6SHA(bytes))
        XCTAssertEqual(descriptor.byteLength, Int64(bytes.count))
        XCTAssertFalse(FileManager.default.fileExists(atPath: temp.path))

        let finalURL = temp.deletingPathExtension()
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalURL.path))
        let attrs = try FileManager.default.attributesOfItem(atPath: finalURL.path)
        XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.intValue, 0o600)

        let loaded = try await store.loadManifest(recordingID: recordingID)
        XCTAssertEqual(try XCTUnwrap(loaded).chunks, [descriptor])

        let journal = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(journal.events.map(\.kind), [.chunkPrepared, .chunkCommitted])
        XCTAssertNil(journal.events.first?.sha256)
        XCTAssertEqual(journal.events.last?.sha256, descriptor.sha256)
    }

    func testMemoryChunkCommitV6RejectsInvalidCAFBeforePreparedJournalOrRename() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateChunkV6Invalid-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        let committer = SuperDictateMemoryAudioChunkCommitter(store: store)
        let temp = try await committer.temporaryChunkURL(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: chunkID
        )
        try Data("not-caf".utf8).write(to: temp)

        do {
            _ = try await committer.commitChunk(
                recordingID: recordingID,
                source: .microphone,
                sequence: 0,
                chunkID: chunkID,
                temporaryURL: temp,
                sessionStartMilliseconds: 0,
                sessionEndMilliseconds: 100,
                sampleRate: 48_000,
                channelCount: 1
            )
            XCTFail("invalid CAF must fail before durability boundary")
        } catch {
            XCTAssertEqual(error as? SuperDictateMemoryChunkCommitError, .invalidContainer)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: temp.deletingPathExtension().path))
        let journal = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertTrue(journal.events.isEmpty)
    }

    func testMemoryChunkCommitV6RejectsSymlinkPartialWithoutFollowingTarget() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateChunkV6Symlink-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        let committer = SuperDictateMemoryAudioChunkCommitter(store: store)
        let temp = try await committer.temporaryChunkURL(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: chunkID
        )
        let outside = root.appendingPathComponent("outside.caf")
        try chunkV6CAF("outside").write(to: outside)
        try FileManager.default.createSymbolicLink(at: temp, withDestinationURL: outside)

        do {
            _ = try await committer.commitChunk(
                recordingID: recordingID,
                source: .microphone,
                sequence: 0,
                chunkID: chunkID,
                temporaryURL: temp,
                sessionStartMilliseconds: 0,
                sessionEndMilliseconds: 100,
                sampleRate: 48_000,
                channelCount: 1
            )
            XCTFail("symlink partial must not be followed")
        } catch {
            XCTAssertEqual(error as? SuperDictateMemoryChunkCommitError, .unsafeFileType)
        }

        XCTAssertEqual(try Data(contentsOf: outside), chunkV6CAF("outside"))
        let journal = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertTrue(journal.events.isEmpty)
    }
}
