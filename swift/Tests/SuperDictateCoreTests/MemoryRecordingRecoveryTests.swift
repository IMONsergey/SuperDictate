import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    private func recoveryCAFBytes(_ payload: String) -> Data {
        var data = Data("caff".utf8)
        data.append(Data(payload.utf8))
        return data
    }

    private func preparedRecoveryEvent(
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

    func testMemoryRecoveryReattachesPreparedFinalizedOrphan() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoverOrphan-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let bytes = recoveryCAFBytes("orphan")
        let event = try preparedRecoveryEvent(
            recordingID: recordingID,
            chunkID: chunkID,
            byteLength: Int64(bytes.count)
        )
        try await store.appendRecoveryEvent(event)
        let packageURL = await store.packageURL(recordingID: recordingID)
        let finalURL = packageURL.appendingPathComponent(event.relativePath)
        try bytes.write(to: finalURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: finalURL.path)

        let recovery = SuperDictateMemoryPackageRecovery(store: store)
        let result = try await recovery.recover(recordingID: recordingID)

        XCTAssertEqual(result.state, .recovered)
        XCTAssertEqual(result.recoveredChunkIDs, [chunkID])
        XCTAssertTrue(result.quarantinedFileNames.isEmpty)
        XCTAssertTrue(result.missingChunkIDs.isEmpty)

        let maybeManifest = try await store.loadManifest(recordingID: recordingID)
        let manifest = try XCTUnwrap(maybeManifest)
        XCTAssertEqual(manifest.chunks.count, 1)
        XCTAssertEqual(manifest.chunks.first?.id, chunkID)
        XCTAssertEqual(manifest.chunks.first?.relativePath, event.relativePath)

        let journal = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(journal.latestEventByChunkID[chunkID]?.kind, .chunkCommitted)
    }

    func testMemoryRecoveryQuarantinesUndocumentedFinalizedOrphan() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoverUndocumented-\(UUID().uuidString)", isDirectory: true)
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
        let finalURL = sourceDirectory.appendingPathComponent(
            URL(fileURLWithPath: relativePath).lastPathComponent
        )
        try recoveryCAFBytes("undocumented").write(to: finalURL)

        let result = try await SuperDictateMemoryPackageRecovery(store: store)
            .recover(recordingID: recordingID)

        XCTAssertEqual(result.state, .needsAttention)
        XCTAssertEqual(result.quarantinedFileNames.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: finalURL.path))
        let maybeManifest = try await store.loadManifest(recordingID: recordingID)
        let manifest = try XCTUnwrap(maybeManifest)
        XCTAssertEqual(manifest.state, .needsAttention)
        XCTAssertTrue(manifest.chunks.isEmpty)
    }

    func testMemoryRecoveryQuarantinesPartialChunkWithoutTreatingItAsAudio() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoverPartial-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        let committer = SuperDictateMemoryAudioChunkCommitter(store: store)
        let chunkID = UUID()
        let partial = try await committer.temporaryChunkURL(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: chunkID
        )
        try recoveryCAFBytes("unfinished").write(to: partial)

        let result = try await SuperDictateMemoryPackageRecovery(store: store)
            .recover(recordingID: recordingID)

        XCTAssertEqual(result.state, .needsAttention)
        XCTAssertEqual(result.quarantinedFileNames.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: partial.path))
        let maybeManifest = try await store.loadManifest(recordingID: recordingID)
        let manifest = try XCTUnwrap(maybeManifest)
        XCTAssertEqual(manifest.state, .needsAttention)
        XCTAssertTrue(manifest.chunks.isEmpty)
    }

    func testPreparedJournalEventWithNoSourceBytesIsReportedMissing() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoverMissingPrepared-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        try await store.appendRecoveryEvent(
            preparedRecoveryEvent(
                recordingID: recordingID,
                chunkID: chunkID,
                byteLength: 100
            )
        )

        let result = try await SuperDictateMemoryPackageRecovery(store: store)
            .recover(recordingID: recordingID)
        XCTAssertEqual(result.state, .needsAttention)
        XCTAssertEqual(result.missingChunkIDs, [chunkID])
    }

    func testReadyPackageChecksumCorruptionIsQuarantinedAndDowngraded() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoverChecksum-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        let committer = SuperDictateMemoryAudioChunkCommitter(store: store)
        let chunkID = UUID()
        let partial = try await committer.temporaryChunkURL(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: chunkID
        )
        try recoveryCAFBytes("original").write(to: partial)
        let descriptor = try await committer.commitChunk(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: chunkID,
            temporaryURL: partial,
            sessionStartMilliseconds: 0,
            sessionEndMilliseconds: 100,
            sampleRate: 48_000,
            channelCount: 1
        )
        _ = try await store.beginFinalization(recordingID: recordingID)
        _ = try await store.markReady(recordingID: recordingID)

        let packageURL = await store.packageURL(recordingID: recordingID)
        let finalURL = packageURL.appendingPathComponent(descriptor.relativePath)
        let handle = try FileHandle(forWritingTo: finalURL)
        try handle.seek(toOffset: 4)
        try handle.write(contentsOf: Data([0x58]))
        try handle.close()

        let result = try await SuperDictateMemoryPackageRecovery(store: store)
            .recover(recordingID: recordingID)

        XCTAssertEqual(result.state, .needsAttention)
        XCTAssertEqual(result.checksumMismatchChunkIDs, [chunkID])
        XCTAssertEqual(result.quarantinedFileNames.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: finalURL.path))
        let maybeManifest = try await store.loadManifest(recordingID: recordingID)
        let manifest = try XCTUnwrap(maybeManifest)
        XCTAssertEqual(manifest.state, .needsAttention)
        XCTAssertEqual(manifest.chunks.map(\.id), [chunkID])
    }

    func testReadyPackageMissingManifestSourceIsReported() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoverMissing-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        let committer = SuperDictateMemoryAudioChunkCommitter(store: store)
        let chunkID = UUID()
        let partial = try await committer.temporaryChunkURL(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: chunkID
        )
        try recoveryCAFBytes("missing").write(to: partial)
        let descriptor = try await committer.commitChunk(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: chunkID,
            temporaryURL: partial,
            sessionStartMilliseconds: 0,
            sessionEndMilliseconds: 100,
            sampleRate: 48_000,
            channelCount: 1
        )
        _ = try await store.beginFinalization(recordingID: recordingID)
        _ = try await store.markReady(recordingID: recordingID)

        let packageURL = await store.packageURL(recordingID: recordingID)
        let finalURL = packageURL.appendingPathComponent(descriptor.relativePath)
        try FileManager.default.removeItem(at: finalURL)

        let result = try await SuperDictateMemoryPackageRecovery(store: store)
            .recover(recordingID: recordingID)
        XCTAssertEqual(result.state, .needsAttention)
        XCTAssertEqual(result.missingChunkIDs, [chunkID])
        let maybeManifest = try await store.loadManifest(recordingID: recordingID)
        let manifest = try XCTUnwrap(maybeManifest)
        XCTAssertEqual(manifest.state, .needsAttention)
    }

    func testTornJournalTailWithHealthyManifestIsQuietlyRecovered() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoverJournalTail-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        let committer = SuperDictateMemoryAudioChunkCommitter(store: store)
        let chunkID = UUID()
        let partial = try await committer.temporaryChunkURL(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: chunkID
        )
        try recoveryCAFBytes("healthy").write(to: partial)
        _ = try await committer.commitChunk(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: chunkID,
            temporaryURL: partial,
            sessionStartMilliseconds: 0,
            sessionEndMilliseconds: 100,
            sampleRate: 48_000,
            channelCount: 1
        )

        let journalURL = await store.recoveryJournalURL(recordingID: recordingID)
        let handle = try FileHandle(forWritingTo: journalURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{\"id\":".utf8))
        try handle.close()

        let result = try await SuperDictateMemoryPackageRecovery(store: store)
            .recover(recordingID: recordingID)
        XCTAssertEqual(result.state, .recovered)
        XCTAssertTrue(result.ignoredPartialJournalTail)
        XCTAssertTrue(result.missingChunkIDs.isEmpty)
        XCTAssertTrue(result.quarantinedFileNames.isEmpty)
    }
}
