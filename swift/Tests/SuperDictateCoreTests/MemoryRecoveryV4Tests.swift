import CryptoKit
import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    private func recoveryV4CAF(_ payload: String) -> Data {
        var data = Data("caff".utf8)
        data.append(Data(payload.utf8))
        return data
    }

    private func recoveryV4SHA(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func recoveryV4Prepared(
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

    func testPreparedOrphanReattachesAndClosesJournalWithComputedSHA() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoverV4Prepared-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let bytes = recoveryV4CAF("prepared")
        let event = try recoveryV4Prepared(
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

        let manifestMaybe = try await store.loadManifest(recordingID: recordingID)
        let manifest = try XCTUnwrap(manifestMaybe)
        XCTAssertEqual(manifest.chunks.map(\.id), [chunkID])
        XCTAssertEqual(manifest.chunks.first?.sha256, recoveryV4SHA(bytes))

        let journal = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        let latest = try XCTUnwrap(journal.latestEventByChunkID[chunkID])
        XCTAssertEqual(latest.kind, .chunkCommitted)
        XCTAssertEqual(latest.sha256, recoveryV4SHA(bytes))
    }

    func testVerifiedOrphanRepairsReadyManifestWithoutReopeningNormalWriter() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoverV4Ready-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        _ = try await store.beginFinalization(recordingID: recordingID)
        _ = try await store.markReady(recordingID: recordingID)

        let bytes = recoveryV4CAF("ready-orphan")
        let event = try recoveryV4Prepared(
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

        let manifestMaybe = try await store.loadManifest(recordingID: recordingID)
        let manifest = try XCTUnwrap(manifestMaybe)
        XCTAssertEqual(manifest.state, .ready)
        XCTAssertEqual(manifest.chunks.map(\.id), [chunkID])
    }

    func testSameLengthCommittedOrphanTamperingIsQuarantined() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoverV4Tamper-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let original = recoveryV4CAF("AAAA")
        let tampered = recoveryV4CAF("BBBB")
        XCTAssertEqual(original.count, tampered.count)
        let prepared = try recoveryV4Prepared(
            recordingID: recordingID,
            chunkID: chunkID,
            source: .system,
            byteLength: Int64(original.count)
        )
        try await store.appendRecoveryEvent(prepared)
        try await store.appendRecoveryEvent(
            SuperDictateMemoryRecoveryEvent(
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
                sha256: recoveryV4SHA(original)
            )
        )

        let packageURL = await store.packageURL(recordingID: recordingID)
        let finalURL = packageURL.appendingPathComponent(prepared.relativePath)
        try tampered.write(to: finalURL)

        let result = try await SuperDictateMemoryPackageRecovery(store: store)
            .recover(recordingID: recordingID)
        XCTAssertEqual(result.state, .needsAttention)
        XCTAssertEqual(result.checksumMismatchChunkIDs, [chunkID])
        XCTAssertEqual(result.quarantinedFileNames.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: finalURL.path))

        let manifestMaybe = try await store.loadManifest(recordingID: recordingID)
        let manifest = try XCTUnwrap(manifestMaybe)
        XCTAssertTrue(manifest.chunks.isEmpty)
        XCTAssertEqual(manifest.state, .needsAttention)
    }

    func testPreparedEventWithoutSourceBytesIsReportedMissing() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoverV4Missing-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        try await store.appendRecoveryEvent(
            recoveryV4Prepared(
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
