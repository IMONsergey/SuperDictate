import CryptoKit
import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    private func recoverV5CAF(_ payload: String) -> Data {
        var data = Data("caff".utf8)
        data.append(Data(payload.utf8))
        return data
    }

    private func recoverV5SHA(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func recoverV5Prepared(
        recordingID: UUID,
        chunkID: UUID,
        source: SuperDictateMemoryAudioSource = .microphone,
        sequence: Int = 0,
        byteLength: Int64
    ) throws -> SuperDictateMemoryRecoveryEvent {
        try SuperDictateMemoryRecoveryEvent(
            kind: .chunkPrepared,
            recordingID: recordingID,
            chunkID: chunkID,
            source: source,
            sequence: sequence,
            relativePath: SuperDictateMemoryAudioChunk.canonicalRelativePath(
                source: source,
                sequence: sequence,
                chunkID: chunkID
            ),
            sessionStartMilliseconds: Int64(sequence) * 1_000,
            sessionEndMilliseconds: Int64(sequence + 1) * 1_000,
            sampleRate: 48_000,
            channelCount: source == .system ? 2 : 1,
            byteLength: byteLength
        )
    }

    func testV5PreparedOrphanReattachesAndBecomesCommitted() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoverV5Prepared-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let bytes = recoverV5CAF("prepared")
        let event = try recoverV5Prepared(
            recordingID: recordingID,
            chunkID: chunkID,
            byteLength: Int64(bytes.count)
        )
        try await store.appendRecoveryEvent(event)
        let packageURL = await store.packageURL(recordingID: recordingID)
        let finalURL = packageURL.appendingPathComponent(event.relativePath)
        try bytes.write(to: finalURL)

        let result = try await SuperDictateMemoryPackageRecovery(store: store)
            .recover(recordingID: recordingID)
        XCTAssertEqual(result.state, .recovered)
        XCTAssertEqual(result.recoveredChunkIDs, [chunkID])

        let maybeManifest = try await store.loadManifest(recordingID: recordingID)
        let manifest = try XCTUnwrap(maybeManifest)
        XCTAssertEqual(manifest.chunks.map(\.id), [chunkID])
        XCTAssertEqual(manifest.chunks.first?.sha256, recoverV5SHA(bytes))
        let journal = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(journal.latestEventByChunkID[chunkID]?.kind, .chunkCommitted)
        XCTAssertEqual(journal.latestEventByChunkID[chunkID]?.sha256, recoverV5SHA(bytes))
    }

    func testV5VerifiedOrphanRepairsReadyManifestWithoutOpeningNormalWriter() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoverV5Ready-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        _ = try await store.beginFinalization(recordingID: recordingID)
        _ = try await store.markReady(recordingID: recordingID)

        let bytes = recoverV5CAF("ready-orphan")
        let event = try recoverV5Prepared(
            recordingID: recordingID,
            chunkID: chunkID,
            byteLength: Int64(bytes.count)
        )
        try await store.appendRecoveryEvent(event)
        let packageURL = await store.packageURL(recordingID: recordingID)
        try bytes.write(to: packageURL.appendingPathComponent(event.relativePath))

        let result = try await SuperDictateMemoryPackageRecovery(store: store)
            .recover(recordingID: recordingID)
        XCTAssertEqual(result.state, .recovered)
        XCTAssertEqual(result.recoveredChunkIDs, [chunkID])

        let maybeManifest = try await store.loadManifest(recordingID: recordingID)
        let manifest = try XCTUnwrap(maybeManifest)
        XCTAssertEqual(manifest.state, .ready)
        XCTAssertEqual(manifest.chunks.map(\.id), [chunkID])
    }

    func testV5CommittedSameLengthTamperIsQuarantined() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoverV5Tamper-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let original = recoverV5CAF("AAAA")
        let tampered = recoverV5CAF("BBBB")
        XCTAssertEqual(original.count, tampered.count)
        let prepared = try recoverV5Prepared(
            recordingID: recordingID,
            chunkID: chunkID,
            source: .system,
            byteLength: Int64(original.count)
        )
        try await store.appendRecoveryEvent(prepared)
        let committed = try SuperDictateMemoryRecoveryEvent(
            kind: .chunkCommitted,
            recordingID: recordingID,
            chunkID: chunkID,
            source: .system,
            sequence: 0,
            relativePath: prepared.relativePath,
            sessionStartMilliseconds: prepared.sessionStartMilliseconds,
            sessionEndMilliseconds: prepared.sessionEndMilliseconds,
            sampleRate: prepared.sampleRate,
            channelCount: prepared.channelCount,
            byteLength: prepared.byteLength,
            sha256: recoverV5SHA(original)
        )
        try await store.appendRecoveryEvent(committed)

        let packageURL = await store.packageURL(recordingID: recordingID)
        let finalURL = packageURL.appendingPathComponent(prepared.relativePath)
        try tampered.write(to: finalURL)

        let result = try await SuperDictateMemoryPackageRecovery(store: store)
            .recover(recordingID: recordingID)
        XCTAssertEqual(result.state, .needsAttention)
        XCTAssertEqual(result.checksumMismatchChunkIDs, [chunkID])
        XCTAssertEqual(result.quarantinedFileNames.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: finalURL.path))
    }

    func testV5PreparedEventWithoutBytesIsMissingAttention() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoverV5Missing-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        try await store.appendRecoveryEvent(
            recoverV5Prepared(
                recordingID: recordingID,
                chunkID: chunkID,
                byteLength: 1_024
            )
        )

        let result = try await SuperDictateMemoryPackageRecovery(store: store)
            .recover(recordingID: recordingID)
        XCTAssertEqual(result.state, .needsAttention)
        XCTAssertEqual(result.missingChunkIDs, [chunkID])
    }

    func testV5PreexistingAttentionReasonIsPreservedWhenSourceIsHealthy() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoverV5ExistingAttention-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        _ = try await store.markNeedsAttention(
            recordingID: recordingID,
            message: "User review required"
        )

        let result = try await SuperDictateMemoryPackageRecovery(store: store)
            .recover(recordingID: recordingID)
        XCTAssertEqual(result.state, .needsAttention)
        XCTAssertTrue(result.missingChunkIDs.isEmpty)
        XCTAssertTrue(result.checksumMismatchChunkIDs.isEmpty)
        XCTAssertTrue(result.journalConflictChunkIDs.isEmpty)

        let maybeManifest = try await store.loadManifest(recordingID: recordingID)
        let manifest = try XCTUnwrap(maybeManifest)
        XCTAssertEqual(manifest.issue, "User review required")
    }
}
