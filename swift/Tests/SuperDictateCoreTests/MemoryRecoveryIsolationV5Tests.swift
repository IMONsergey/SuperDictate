import CryptoKit
import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    private func isolationV5CAF(_ payload: String) -> Data {
        var data = Data("caff".utf8)
        data.append(Data(payload.utf8))
        return data
    }

    private func isolationV5SHA(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func testV5QuarantineSymlinkAbortsBeforeMovingSource() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoverV5Quarantine-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let sourceDirectory = await store.audioDirectory(recordingID: recordingID, source: .system)
        let relativePath = SuperDictateMemoryAudioChunk.canonicalRelativePath(
            source: .system,
            sequence: 0,
            chunkID: chunkID
        )
        let sourceURL = sourceDirectory.appendingPathComponent(
            URL(fileURLWithPath: relativePath).lastPathComponent
        )
        try isolationV5CAF("undocumented").write(to: sourceURL)

        let quarantineURL = await store.quarantineDirectory(recordingID: recordingID)
        try FileManager.default.removeItem(at: quarantineURL)
        let outside = root.appendingPathComponent("outside-quarantine", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: quarantineURL, withDestinationURL: outside)

        do {
            _ = try await SuperDictateMemoryPackageRecovery(store: store)
                .recover(recordingID: recordingID)
            XCTFail("quarantine symlink must abort recovery")
        } catch {
            XCTAssertEqual(
                error as? SuperDictateMemoryRecoveryError,
                .unsafeFileType("quarantine")
            )
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: outside.path).isEmpty)
    }

    func testV5BatchRecoveryContinuesPastUnreadablePackage() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoverV5Batch-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)

        let healthyID = UUID()
        _ = try await store.createPackage(recordingID: healthyID)

        let brokenID = UUID()
        _ = try await store.createPackage(recordingID: brokenID)
        let brokenManifest = await store.manifestURL(recordingID: brokenID)
        try FileManager.default.removeItem(at: brokenManifest)
        let outside = root.appendingPathComponent("outside.json")
        try Data("{}".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: brokenManifest, withDestinationURL: outside)

        let batch = try await SuperDictateMemoryPackageRecovery(store: store).recoverAll()
        XCTAssertEqual(batch.results.map(\.recordingID), [healthyID])
        XCTAssertEqual(batch.results.first?.state, .valid)
        XCTAssertEqual(batch.failedRecordingIDs, [brokenID])
    }

    func testV5ManifestCommittedSourceClosesPreparedJournalMarker() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoverV5ClosePrepared-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let bytes = isolationV5CAF("manifest-won")
        let relativePath = SuperDictateMemoryAudioChunk.canonicalRelativePath(
            source: .microphone,
            sequence: 0,
            chunkID: chunkID
        )
        let prepared = try SuperDictateMemoryRecoveryEvent(
            kind: .chunkPrepared,
            recordingID: recordingID,
            chunkID: chunkID,
            source: .microphone,
            sequence: 0,
            relativePath: relativePath,
            sessionStartMilliseconds: 0,
            sessionEndMilliseconds: 100,
            sampleRate: 48_000,
            channelCount: 1,
            byteLength: Int64(bytes.count)
        )
        try await store.appendRecoveryEvent(prepared)

        let packageURL = await store.packageURL(recordingID: recordingID)
        let finalURL = packageURL.appendingPathComponent(relativePath)
        try bytes.write(to: finalURL)
        let descriptor = try SuperDictateMemoryAudioChunk(
            id: chunkID,
            source: .microphone,
            sequence: 0,
            relativePath: relativePath,
            sessionStartMilliseconds: 0,
            sessionEndMilliseconds: 100,
            sampleRate: 48_000,
            channelCount: 1,
            byteLength: Int64(bytes.count),
            sha256: isolationV5SHA(bytes)
        )
        _ = try await store.appendFinalizedChunk(recordingID: recordingID, chunk: descriptor)

        let result = try await SuperDictateMemoryPackageRecovery(store: store)
            .recover(recordingID: recordingID)
        XCTAssertEqual(result.state, .valid)
        XCTAssertTrue(result.journalConflictChunkIDs.isEmpty)

        let journal = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(journal.latestEventByChunkID[chunkID]?.kind, .chunkCommitted)
        XCTAssertEqual(journal.latestEventByChunkID[chunkID]?.sha256, descriptor.sha256)
    }

    func testV5JournalMetadataConflictPreservesValidSourceButMarksAttention() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoverV5JournalConflict-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let bytes = isolationV5CAF("valid-source")
        let relativePath = SuperDictateMemoryAudioChunk.canonicalRelativePath(
            source: .microphone,
            sequence: 0,
            chunkID: chunkID
        )
        let prepared = try SuperDictateMemoryRecoveryEvent(
            kind: .chunkPrepared,
            recordingID: recordingID,
            chunkID: chunkID,
            source: .microphone,
            sequence: 0,
            relativePath: relativePath,
            sessionStartMilliseconds: 0,
            sessionEndMilliseconds: 90,
            sampleRate: 48_000,
            channelCount: 1,
            byteLength: Int64(bytes.count)
        )
        try await store.appendRecoveryEvent(prepared)

        let packageURL = await store.packageURL(recordingID: recordingID)
        let finalURL = packageURL.appendingPathComponent(relativePath)
        try bytes.write(to: finalURL)
        let descriptor = try SuperDictateMemoryAudioChunk(
            id: chunkID,
            source: .microphone,
            sequence: 0,
            relativePath: relativePath,
            sessionStartMilliseconds: 0,
            sessionEndMilliseconds: 100,
            sampleRate: 48_000,
            channelCount: 1,
            byteLength: Int64(bytes.count),
            sha256: isolationV5SHA(bytes)
        )
        _ = try await store.appendFinalizedChunk(recordingID: recordingID, chunk: descriptor)

        let result = try await SuperDictateMemoryPackageRecovery(store: store)
            .recover(recordingID: recordingID)
        XCTAssertEqual(result.state, .needsAttention)
        XCTAssertEqual(result.journalConflictChunkIDs, [chunkID])
        XCTAssertTrue(result.quarantinedFileNames.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalURL.path))
    }
}
