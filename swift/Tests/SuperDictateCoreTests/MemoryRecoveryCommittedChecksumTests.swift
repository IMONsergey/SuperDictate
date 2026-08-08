import CryptoKit
import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    private func recoveryChecksumCAF(_ payload: String) -> Data {
        var data = Data("caff".utf8)
        data.append(Data(payload.utf8))
        return data
    }

    private func recoveryChecksumSHA(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func testInvalidCAFIsRejectedForTheMatchingTemporaryChunkIdentity() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateInvalidCAFIdentity-\(UUID().uuidString)", isDirectory: true)
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
            XCTFail("invalid CAF must fail before rename")
        } catch {
            XCTAssertEqual(error as? SuperDictateMemoryChunkCommitError, .invalidContainer)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.path))
    }

    func testCommittedOrphanWithSameLengthTamperedBytesIsQuarantined() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateCommittedTamper-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let original = recoveryChecksumCAF("AAAA")
        let tampered = recoveryChecksumCAF("BBBB")
        XCTAssertEqual(original.count, tampered.count)
        let relativePath = SuperDictateMemoryAudioChunk.canonicalRelativePath(
            source: .system,
            sequence: 0,
            chunkID: chunkID
        )
        let committed = try SuperDictateMemoryRecoveryEvent(
            kind: .chunkCommitted,
            recordingID: recordingID,
            chunkID: chunkID,
            source: .system,
            sequence: 0,
            relativePath: relativePath,
            sessionStartMilliseconds: 0,
            sessionEndMilliseconds: 100,
            sampleRate: 48_000,
            channelCount: 2,
            byteLength: Int64(original.count),
            sha256: recoveryChecksumSHA(original)
        )
        try await store.appendRecoveryEvent(committed)

        let packageURL = await store.packageURL(recordingID: recordingID)
        let finalURL = packageURL.appendingPathComponent(relativePath)
        try tampered.write(to: finalURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: finalURL.path)

        let result = try await SuperDictateMemoryPackageRecovery(store: store)
            .recover(recordingID: recordingID)

        XCTAssertEqual(result.state, .needsAttention)
        XCTAssertEqual(result.checksumMismatchChunkIDs, [chunkID])
        XCTAssertEqual(result.quarantinedFileNames.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: finalURL.path))
        let maybeManifest = try await store.loadManifest(recordingID: recordingID)
        let manifest = try XCTUnwrap(maybeManifest)
        XCTAssertTrue(manifest.chunks.isEmpty)
        XCTAssertEqual(manifest.state, .needsAttention)
    }
}
