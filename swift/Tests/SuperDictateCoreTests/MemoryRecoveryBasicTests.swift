import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    private func basicRecoveryCAF(_ payload: String) -> Data {
        var data = Data("caff".utf8)
        data.append(Data(payload.utf8))
        return data
    }

    private func basicPreparedEvent(
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

    func testPreparedFinalizedOrphanIsReattachedAndClosedWithCommittedMarker() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictatePreparedRecoverV2-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let bytes = basicRecoveryCAF("prepared-orphan")
        let event = try basicPreparedEvent(
            recordingID: recordingID,
            chunkID: chunkID,
            byteLength: Int64(bytes.count)
        )
        try await store.appendRecoveryEvent(event)

        let packageURL = await store.packageURL(recordingID: recordingID)
        let finalURL = packageURL.appendingPathComponent(event.relativePath)
        try bytes.write(to: finalURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: finalURL.path
        )

        let result = try await SuperDictateMemoryPackageRecovery(store: store)
            .recover(recordingID: recordingID)
        XCTAssertEqual(result.state, .recovered)
        XCTAssertEqual(result.recoveredChunkIDs, [chunkID])
        XCTAssertTrue(result.missingChunkIDs.isEmpty)
        XCTAssertTrue(result.quarantinedFileNames.isEmpty)

        let maybeManifest = try await store.loadManifest(recordingID: recordingID)
        let manifest = try XCTUnwrap(maybeManifest)
        XCTAssertEqual(manifest.chunks.map(\.id), [chunkID])

        let journal = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        let latest = try XCTUnwrap(journal.latestEventByChunkID[chunkID])
        XCTAssertEqual(latest.kind, .chunkCommitted)
        XCTAssertNotNil(latest.sha256)
        XCTAssertEqual(latest.sha256, manifest.chunks.first?.sha256)
    }

    func testUndocumentedFinalCAFIsQuarantinedAndMarksPackageAttention() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateUndocumentedRecoverV2-\(UUID().uuidString)", isDirectory: true)
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
        let finalURL = sourceDirectory.appendingPathComponent(
            URL(fileURLWithPath: relativePath).lastPathComponent
        )
        try basicRecoveryCAF("undocumented").write(to: finalURL)

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

    func testPreparedJournalEntryWithoutAnySourceBytesIsReportedMissing() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateMissingPreparedV2-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        try await store.appendRecoveryEvent(
            basicPreparedEvent(
                recordingID: recordingID,
                chunkID: chunkID,
                byteLength: 512
            )
        )

        let result = try await SuperDictateMemoryPackageRecovery(store: store)
            .recover(recordingID: recordingID)
        XCTAssertEqual(result.state, .needsAttention)
        XCTAssertEqual(result.missingChunkIDs, [chunkID])

        let maybeManifest = try await store.loadManifest(recordingID: recordingID)
        XCTAssertEqual(try XCTUnwrap(maybeManifest).state, .needsAttention)
    }

    func testTornFinalJournalLineWithHealthyManifestIsQuietRecovery() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateTornTailV2-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        let committer = SuperDictateMemoryAudioChunkCommitter(store: store)
        let temporaryURL = try await committer.temporaryChunkURL(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: chunkID
        )
        try basicRecoveryCAF("healthy").write(to: temporaryURL)
        _ = try await committer.commitChunk(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: chunkID,
            temporaryURL: temporaryURL,
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
        XCTAssertTrue(result.checksumMismatchChunkIDs.isEmpty)
        XCTAssertTrue(result.quarantinedFileNames.isEmpty)

        let maybeManifest = try await store.loadManifest(recordingID: recordingID)
        XCTAssertNotEqual(try XCTUnwrap(maybeManifest).state, .needsAttention)
    }
}
