import CryptoKit
import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    private func memoryV6CAF(_ payload: String) -> Data {
        var data = Data("caff".utf8)
        data.append(Data(payload.utf8))
        return data
    }

    private func memoryV6SHA(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func memoryV6Event(
        kind: SuperDictateMemoryRecoveryEventKind,
        recordingID: UUID,
        chunkID: UUID,
        source: SuperDictateMemoryAudioSource = .microphone,
        sequence: Int = 0,
        byteLength: Int64,
        sha256: String? = nil
    ) throws -> SuperDictateMemoryRecoveryEvent {
        try SuperDictateMemoryRecoveryEvent(
            kind: kind,
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
            byteLength: byteLength,
            sha256: sha256
        )
    }

    func testMemoryRecoveryV6ReattachesPreparedOrphanWithoutReopeningReadyPackage() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoveryV6Ready-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        _ = try await store.beginFinalization(recordingID: recordingID)
        _ = try await store.markReady(recordingID: recordingID)

        let bytes = memoryV6CAF("ready-orphan")
        let prepared = try memoryV6Event(
            kind: .chunkPrepared,
            recordingID: recordingID,
            chunkID: chunkID,
            byteLength: Int64(bytes.count)
        )
        try await store.appendRecoveryEvent(prepared)

        let packageURL = await store.packageURL(recordingID: recordingID)
        let finalURL = packageURL.appendingPathComponent(prepared.relativePath)
        try bytes.write(to: finalURL)

        let result = try await SuperDictateMemoryPackageRecovery(store: store)
            .recover(recordingID: recordingID)
        XCTAssertEqual(result.state, .recovered)
        XCTAssertEqual(result.recoveredChunkIDs, [chunkID])
        XCTAssertTrue(result.quarantinedFileNames.isEmpty)

        let loaded = try await store.loadManifest(recordingID: recordingID)
        let manifest = try XCTUnwrap(loaded)
        XCTAssertEqual(manifest.state, .ready)
        XCTAssertEqual(manifest.chunks.map(\.id), [chunkID])
        XCTAssertEqual(manifest.chunks.first?.sha256, memoryV6SHA(bytes))

        let journal = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(journal.latestEventByChunkID[chunkID]?.kind, .chunkCommitted)
        XCTAssertEqual(journal.latestEventByChunkID[chunkID]?.sha256, memoryV6SHA(bytes))
    }

    func testMemoryRecoveryV6RejectsSameSizeTamperForCommittedOrphan() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoveryV6Tamper-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let original = memoryV6CAF("AAAA")
        let tampered = memoryV6CAF("BBBB")
        XCTAssertEqual(original.count, tampered.count)

        let prepared = try memoryV6Event(
            kind: .chunkPrepared,
            recordingID: recordingID,
            chunkID: chunkID,
            byteLength: Int64(original.count)
        )
        let committed = try memoryV6Event(
            kind: .chunkCommitted,
            recordingID: recordingID,
            chunkID: chunkID,
            byteLength: Int64(original.count),
            sha256: memoryV6SHA(original)
        )
        try await store.appendRecoveryEvent(prepared)
        try await store.appendRecoveryEvent(committed)

        let packageURL = await store.packageURL(recordingID: recordingID)
        let finalURL = packageURL.appendingPathComponent(committed.relativePath)
        try tampered.write(to: finalURL)

        let result = try await SuperDictateMemoryPackageRecovery(store: store)
            .recover(recordingID: recordingID)
        XCTAssertEqual(result.state, .needsAttention)
        XCTAssertEqual(result.checksumMismatchChunkIDs, [chunkID])
        XCTAssertEqual(result.quarantinedFileNames.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: finalURL.path))

        let loaded = try await store.loadManifest(recordingID: recordingID)
        let manifest = try XCTUnwrap(loaded)
        XCTAssertEqual(manifest.state, .needsAttention)
        XCTAssertTrue(manifest.chunks.isEmpty)
    }

    func testMemoryRecoveryV6ClosesPreparedJournalForAlreadyPersistedManifestChunk() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoveryV6CloseJournal-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let bytes = memoryV6CAF("manifest-already-durable")
        let prepared = try memoryV6Event(
            kind: .chunkPrepared,
            recordingID: recordingID,
            chunkID: chunkID,
            byteLength: Int64(bytes.count)
        )
        try await store.appendRecoveryEvent(prepared)

        let packageURL = await store.packageURL(recordingID: recordingID)
        let finalURL = packageURL.appendingPathComponent(prepared.relativePath)
        try bytes.write(to: finalURL)
        let descriptor = try SuperDictateMemoryAudioChunk(
            id: chunkID,
            source: prepared.source,
            sequence: prepared.sequence,
            relativePath: prepared.relativePath,
            sessionStartMilliseconds: prepared.sessionStartMilliseconds,
            sessionEndMilliseconds: prepared.sessionEndMilliseconds,
            sampleRate: prepared.sampleRate,
            channelCount: prepared.channelCount,
            byteLength: Int64(bytes.count),
            sha256: memoryV6SHA(bytes)
        )
        _ = try await store.appendFinalizedChunk(
            recordingID: recordingID,
            chunk: descriptor
        )

        let result = try await SuperDictateMemoryPackageRecovery(store: store)
            .recover(recordingID: recordingID)
        XCTAssertEqual(result.state, .valid)
        XCTAssertTrue(result.recoveredChunkIDs.isEmpty)

        let journal = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(journal.latestEventByChunkID[chunkID]?.kind, .chunkCommitted)
        XCTAssertEqual(journal.latestEventByChunkID[chunkID]?.sha256, descriptor.sha256)
    }

    func testMemoryRecoveryV6PreservesPreexistingAttentionWhenSourceIsHealthy() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoveryV6ExistingAttention-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        _ = try await store.markNeedsAttention(
            recordingID: recordingID,
            message: "Needs user review"
        )

        let result = try await SuperDictateMemoryPackageRecovery(store: store)
            .recover(recordingID: recordingID)
        XCTAssertEqual(result.state, .needsAttention)
        XCTAssertTrue(result.missingChunkIDs.isEmpty)
        XCTAssertTrue(result.quarantinedFileNames.isEmpty)

        let loaded = try await store.loadManifest(recordingID: recordingID)
        XCTAssertEqual(try XCTUnwrap(loaded).issue, "Needs user review")
    }

    func testMemoryRecoveryV6BatchReportsUnsafeUUIDNamedPackageInsteadOfHidingIt() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoveryV6Batch-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let validID = UUID()
        let unsafeID = UUID()
        _ = try await store.createPackage(recordingID: validID)

        let unsafePackageURL = await store.packageURL(recordingID: unsafeID)
        let outside = root.appendingPathComponent("outside-package", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: unsafePackageURL,
            withDestinationURL: outside
        )

        let batch = try await SuperDictateMemoryPackageRecovery(store: store).recoverAll()
        XCTAssertEqual(batch.results.map(\.recordingID), [validID])
        XCTAssertEqual(batch.failedRecordingIDs, [unsafeID])
    }

    func testMemoryRecoveryV6RejectsSymlinkQuarantineBeforeMovingSource() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoveryV6Quarantine-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let sourceDirectory = await store.audioDirectory(
            recordingID: recordingID,
            source: .system
        )
        let relativePath = SuperDictateMemoryAudioChunk.canonicalRelativePath(
            source: .system,
            sequence: 0,
            chunkID: chunkID
        )
        let sourceURL = sourceDirectory.appendingPathComponent(
            URL(fileURLWithPath: relativePath).lastPathComponent
        )
        try memoryV6CAF("undocumented").write(to: sourceURL)

        let quarantineURL = await store.quarantineDirectory(recordingID: recordingID)
        try FileManager.default.removeItem(at: quarantineURL)
        let outside = root.appendingPathComponent("outside-quarantine", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: quarantineURL,
            withDestinationURL: outside
        )

        do {
            _ = try await SuperDictateMemoryPackageRecovery(store: store)
                .recover(recordingID: recordingID)
            XCTFail("symlink quarantine must abort before source movement")
        } catch {
            // Exact errno differs across Darwin filesystem configurations; the
            // source-preservation assertions below are the security contract.
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(
            try FileManager.default.contentsOfDirectory(atPath: outside.path).isEmpty
        )
    }
}
