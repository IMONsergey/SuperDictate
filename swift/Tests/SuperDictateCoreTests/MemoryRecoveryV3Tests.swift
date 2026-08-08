import CryptoKit
import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    private func v3CAF(_ payload: String) -> Data {
        var data = Data("caff".utf8)
        data.append(Data(payload.utf8))
        return data
    }

    private func v3SHA(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func v3PreparedEvent(
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

    func testPreparedOrphanReattachesAndBecomesSHACommitted() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoveryV3Prepared-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let bytes = v3CAF("prepared")
        let event = try v3PreparedEvent(
            recordingID: recordingID,
            chunkID: chunkID,
            byteLength: Int64(bytes.count)
        )
        try await store.appendRecoveryEvent(event)
        let packageURL = await store.packageURL(recordingID: recordingID)
        let finalURL = packageURL.appendingPathComponent(event.relativePath)
        try bytes.write(to: finalURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: finalURL.path)

        let result = try await SuperDictateMemoryPackageRecovery(store: store)
            .recover(recordingID: recordingID)
        XCTAssertEqual(result.state, .recovered)
        XCTAssertEqual(result.recoveredChunkIDs, [chunkID])
        XCTAssertTrue(result.journalConflictChunkIDs.isEmpty)

        let manifest = try XCTUnwrap(try await store.loadManifest(recordingID: recordingID))
        XCTAssertEqual(manifest.chunks.map(\.id), [chunkID])
        XCTAssertEqual(manifest.chunks.first?.sha256, v3SHA(bytes))
        let journal = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(journal.latestEventByChunkID[chunkID]?.kind, .chunkCommitted)
        XCTAssertEqual(journal.latestEventByChunkID[chunkID]?.sha256, v3SHA(bytes))
    }

    func testVerifiedOrphanCanRepairAlreadyReadyManifestWithoutReopeningWriter() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoveryV3Ready-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        _ = try await store.beginFinalization(recordingID: recordingID)
        _ = try await store.markReady(recordingID: recordingID)

        let bytes = v3CAF("ready-orphan")
        let event = try v3PreparedEvent(
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

        let manifest = try XCTUnwrap(try await store.loadManifest(recordingID: recordingID))
        XCTAssertEqual(manifest.state, .ready)
        XCTAssertEqual(manifest.chunks.map(\.id), [chunkID])
    }

    func testCommittedOrphanWithSameLengthTamperingIsQuarantined() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoveryV3Tamper-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let original = v3CAF("AAAA")
        let tampered = v3CAF("BBBB")
        XCTAssertEqual(original.count, tampered.count)
        let prepared = try v3PreparedEvent(
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
            sha256: v3SHA(original)
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

        let manifest = try XCTUnwrap(try await store.loadManifest(recordingID: recordingID))
        XCTAssertTrue(manifest.chunks.isEmpty)
        XCTAssertEqual(manifest.state, .needsAttention)
    }

    func testPreparedEventWithoutSourceBytesIsMissingAttention() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoveryV3Missing-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        try await store.appendRecoveryEvent(
            v3PreparedEvent(
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
}
