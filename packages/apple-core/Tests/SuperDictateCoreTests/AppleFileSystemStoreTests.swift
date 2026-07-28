import Foundation
import XCTest
@testable import SuperDictateCore

final class AppleFileSystemStoreTests: XCTestCase {
    func testManifestRoundTripPreservesPolicyChunksAndMarkers() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let startedAt = Date(timeIntervalSince1970: 100.125)
        let descriptor = RecordingDescriptor(
            sourcePlatform: .watchOS,
            mode: .quickThought,
            startedAt: startedAt,
            localeIdentifier: "ru_RU"
        )
        let assetID = UUID()
        let chunk = try AudioChunkDescriptor(
            assetID: assetID,
            sequence: 0,
            byteCount: 1_024,
            durationMilliseconds: 5_000,
            checksum: "sha256:abc",
            createdAt: startedAt.addingTimeInterval(1),
            persistenceState: .verified
        )
        let marker = RecordingMarker(
            offsetMilliseconds: 2_000,
            kind: .task,
            note: "Follow up",
            createdAt: startedAt.addingTimeInterval(2)
        )
        let manifest = try LocalRecordingManifest(
            descriptor: descriptor,
            productPolicy: RecordingMode.quickThought.defaultProductPolicy,
            localState: .queued,
            chunks: [chunk],
            markers: [marker],
            transferRoute: .companion,
            createdAt: startedAt,
            updatedAt: startedAt.addingTimeInterval(3)
        )
        let store = try JSONRecordingManifestStore(rootDirectory: root)

        try await store.save(manifest)
        let loaded = try await store.load(recordingID: manifest.id)

        XCTAssertEqual(loaded, manifest)
    }

    func testManifestOverwritePersistsLatestRevisionAtomically() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let descriptor = RecordingDescriptor(
            sourcePlatform: .iOS,
            mode: .meeting,
            startedAt: Date(timeIntervalSince1970: 100)
        )
        var manifest = try LocalRecordingManifest(
            descriptor: descriptor,
            productPolicy: RecordingMode.meeting.defaultProductPolicy,
            localState: .finalized
        )
        let store = try JSONRecordingManifestStore(rootDirectory: root)

        try await store.save(manifest)
        manifest.localState = .queued
        manifest.manifestRevision += 1
        manifest.updatedAt = Date(timeIntervalSince1970: 200)
        try await store.save(manifest)

        let loaded = try await store.load(recordingID: manifest.id)
        XCTAssertEqual(loaded?.manifestRevision, 2)
        XCTAssertEqual(loaded?.localState, .queued)
        XCTAssertEqual(loaded?.updatedAt, Date(timeIntervalSince1970: 200))
    }

    func testListPendingTransferExcludesReadyRecordings() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONRecordingManifestStore(rootDirectory: root)
        let queued = try makeManifest(
            platform: .watchOS,
            mode: .quickThought,
            state: .queued,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let attention = try makeManifest(
            platform: .iOS,
            mode: .meeting,
            state: .needsAttention,
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        let ready = try makeManifest(
            platform: .macOS,
            mode: .dictation,
            state: .ready,
            updatedAt: Date(timeIntervalSince1970: 50)
        )

        try await store.save(attention)
        try await store.save(ready)
        try await store.save(queued)

        let pending = try await store.listPendingTransfer()

        XCTAssertEqual(pending.map(\.id), [queued.id, attention.id])
    }

    func testRemoveLocalSourceDeletesPackage() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let manifest = try makeManifest(
            platform: .watchOS,
            mode: .dailyMemory,
            state: .finalized,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let store = try JSONRecordingManifestStore(rootDirectory: root)
        try await store.save(manifest)
        let packageURL = await store.packageURL(recordingID: manifest.id)

        XCTAssertTrue(FileManager.default.fileExists(atPath: packageURL.path))

        try await store.removeLocalSource(recordingID: manifest.id)
        let loaded = try await store.load(recordingID: manifest.id)

        XCTAssertNil(loaded)
        XCTAssertFalse(FileManager.default.fileExists(atPath: packageURL.path))
    }

    func testQueueRoundTripPreservesAttemptsAndFailure() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let date = Date(timeIntervalSince1970: 100)
        var queue = UploadQueue()
        let entry = queue.enqueue(
            recordingID: UUID(),
            priority: 5,
            route: .direct,
            at: date
        )
        try queue.markStarted(entryID: entry.id, at: date)
        try queue.markFailed(
            entryID: entry.id,
            failure: SyncFailure(
                code: "offline",
                message: "Offline",
                classification: .recoverable
            ),
            at: date,
            backoff: RetryBackoffPolicy(
                initialDelay: 10,
                multiplier: 2,
                maximumDelay: 60
            )
        )
        let store = try JSONUploadQueueStore(rootDirectory: root)

        try await store.saveQueue(queue)
        let loaded = try await store.loadQueue()

        XCTAssertEqual(loaded, queue)
    }

    func testMissingQueueReturnsEmptyQueue() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONUploadQueueStore(rootDirectory: root)
        let queue = try await store.loadQueue()

        XCTAssertTrue(queue.entries.isEmpty)
    }

    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateCoreTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        return root
    }

    private func makeManifest(
        platform: SourcePlatform,
        mode: RecordingMode,
        state: LocalRecordingState,
        updatedAt: Date
    ) throws -> LocalRecordingManifest {
        let descriptor = RecordingDescriptor(
            sourcePlatform: platform,
            mode: mode,
            startedAt: updatedAt.addingTimeInterval(-10)
        )
        return try LocalRecordingManifest(
            descriptor: descriptor,
            productPolicy: mode.defaultProductPolicy,
            localState: state,
            createdAt: updatedAt.addingTimeInterval(-10),
            updatedAt: updatedAt
        )
    }
}
