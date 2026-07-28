import Foundation
import XCTest
@testable import SuperDictateCore

private actor TestManifestStore: RecordingManifestStore {
    private var manifests: [UUID: LocalRecordingManifest]

    init(manifests: [UUID: LocalRecordingManifest] = [:]) {
        self.manifests = manifests
    }

    func load(recordingID: UUID) async throws -> LocalRecordingManifest? {
        manifests[recordingID]
    }

    func save(_ manifest: LocalRecordingManifest) async throws {
        manifests[manifest.id] = manifest
    }

    func listPendingTransfer() async throws -> [LocalRecordingManifest] {
        manifests.values.filter { manifest in
            [.finalized, .queued, .transferring, .needsAttention]
                .contains(manifest.localState)
        }
    }

    func removeLocalSource(recordingID: UUID) async throws {
        manifests.removeValue(forKey: recordingID)
    }

    func snapshot(recordingID: UUID) -> LocalRecordingManifest? {
        manifests[recordingID]
    }
}

private actor TestQueueStore: UploadQueueStore {
    private var queue: UploadQueue

    init(queue: UploadQueue = UploadQueue()) {
        self.queue = queue
    }

    func loadQueue() async throws -> UploadQueue {
        queue
    }

    func saveQueue(_ queue: UploadQueue) async throws {
        self.queue = queue
    }

    func snapshot() -> UploadQueue {
        queue
    }
}

private actor TestUploadTransport: RecordingUploadTransport {
    enum Behavior: Sendable {
        case succeed(TransferAcknowledgementLevel)
        case fail(SyncFailure)
    }

    private var behavior: Behavior
    private var calls = 0

    init(behavior: Behavior) {
        self.behavior = behavior
    }

    func upload(
        manifest: LocalRecordingManifest,
        queueEntry: UploadQueueEntry
    ) async throws -> TransferAcknowledgementLevel {
        calls += 1

        switch behavior {
        case let .succeed(level):
            return level
        case let .fail(failure):
            throw failure
        }
    }

    func callCount() -> Int {
        calls
    }
}

final class UploadQueueCoordinatorTests: XCTestCase {
    func testRunNextReturnsNoWorkForEmptyQueue() async throws {
        let coordinator = UploadQueueCoordinator(
            manifestStore: TestManifestStore(),
            queueStore: TestQueueStore(),
            transport: TestUploadTransport(behavior: .succeed(.uploadedToServer))
        )

        let result = try await coordinator.runNext(
            at: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(result, .noWork)
    }

    func testSuccessfulUploadPersistsAcknowledgementBeforeCompletingQueue() async throws {
        let date = Date(timeIntervalSince1970: 100)
        let descriptor = RecordingDescriptor(
            sourcePlatform: .watchOS,
            mode: .quickThought,
            startedAt: date
        )
        let manifest = try LocalRecordingManifest(
            descriptor: descriptor,
            productPolicy: RecordingMode.quickThought.defaultProductPolicy,
            localState: .queued
        )
        let manifestStore = TestManifestStore(
            manifests: [manifest.id: manifest]
        )
        var queue = UploadQueue()
        let entry = queue.enqueue(
            recordingID: manifest.id,
            route: .companion,
            at: date
        )
        let queueStore = TestQueueStore(queue: queue)
        let transport = TestUploadTransport(
            behavior: .succeed(.serverManifestCommitted)
        )
        let coordinator = UploadQueueCoordinator(
            manifestStore: manifestStore,
            queueStore: queueStore,
            transport: transport
        )

        let result = try await coordinator.runNext(at: date)

        XCTAssertEqual(
            result,
            .completed(
                recordingID: manifest.id,
                acknowledgement: .serverManifestCommitted
            )
        )

        let savedManifest = await manifestStore.snapshot(recordingID: manifest.id)
        XCTAssertEqual(savedManifest?.acknowledgementLevel, .serverManifestCommitted)
        XCTAssertEqual(savedManifest?.localState, .uploaded)

        let savedQueue = await queueStore.snapshot()
        XCTAssertEqual(
            savedQueue.entries.first(where: { $0.id == entry.id })?.state,
            .succeeded
        )
        XCTAssertEqual(await transport.callCount(), 1)
    }

    func testRecoverableFailurePersistsRetryAndAttentionState() async throws {
        let date = Date(timeIntervalSince1970: 100)
        let descriptor = RecordingDescriptor(
            sourcePlatform: .iOS,
            mode: .meeting,
            startedAt: date
        )
        let manifest = try LocalRecordingManifest(
            descriptor: descriptor,
            productPolicy: RecordingMode.meeting.defaultProductPolicy,
            localState: .queued
        )
        let manifestStore = TestManifestStore(
            manifests: [manifest.id: manifest]
        )
        var queue = UploadQueue()
        let entry = queue.enqueue(
            recordingID: manifest.id,
            route: .direct,
            at: date
        )
        let queueStore = TestQueueStore(queue: queue)
        let failure = SyncFailure(
            code: "network_unavailable",
            message: "Network unavailable",
            classification: .recoverable
        )
        let coordinator = UploadQueueCoordinator(
            manifestStore: manifestStore,
            queueStore: queueStore,
            transport: TestUploadTransport(behavior: .fail(failure)),
            backoff: RetryBackoffPolicy(
                initialDelay: 10,
                multiplier: 2,
                maximumDelay: 60
            )
        )

        let result = try await coordinator.runNext(at: date)

        XCTAssertEqual(
            result,
            .deferred(recordingID: manifest.id, failure: failure)
        )

        let savedQueue = await queueStore.snapshot()
        let savedEntry = try XCTUnwrap(
            savedQueue.entries.first(where: { $0.id == entry.id })
        )
        XCTAssertEqual(savedEntry.state, .waiting)
        XCTAssertEqual(savedEntry.nextAttemptAt, date.addingTimeInterval(10))

        let savedManifest = await manifestStore.snapshot(recordingID: manifest.id)
        XCTAssertEqual(savedManifest?.localState, .needsAttention)
        XCTAssertEqual(savedManifest?.lastFailure?.retryTarget, .upload)
    }

    func testMissingManifestBecomesPermanentWithoutTransportCall() async throws {
        let date = Date(timeIntervalSince1970: 100)
        let recordingID = UUID()
        var queue = UploadQueue()
        let entry = queue.enqueue(
            recordingID: recordingID,
            route: .companion,
            at: date
        )
        let queueStore = TestQueueStore(queue: queue)
        let transport = TestUploadTransport(
            behavior: .succeed(.uploadedToServer)
        )
        let coordinator = UploadQueueCoordinator(
            manifestStore: TestManifestStore(),
            queueStore: queueStore,
            transport: transport
        )

        let result = try await coordinator.runNext(at: date)

        guard case let .deferred(resultRecordingID, failure) = result else {
            return XCTFail("Expected deferred result")
        }
        XCTAssertEqual(resultRecordingID, recordingID)
        XCTAssertEqual(failure.code, "manifest_missing")
        XCTAssertEqual(failure.classification, .permanent)

        let savedQueue = await queueStore.snapshot()
        XCTAssertEqual(
            savedQueue.entries.first(where: { $0.id == entry.id })?.state,
            .failedPermanent
        )
        XCTAssertEqual(await transport.callCount(), 0)
    }

    func testCoordinatorEnqueueRemainsIdempotent() async throws {
        let recordingID = UUID()
        let queueStore = TestQueueStore()
        let coordinator = UploadQueueCoordinator(
            manifestStore: TestManifestStore(),
            queueStore: queueStore,
            transport: TestUploadTransport(behavior: .succeed(.uploadedToServer))
        )

        let first = try await coordinator.enqueue(
            recordingID: recordingID,
            route: .companion
        )
        let second = try await coordinator.enqueue(
            recordingID: recordingID,
            route: .direct
        )

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual((await queueStore.snapshot()).entries.count, 1)
    }

    func testRecoveryRestoresInterruptedAttempt() async throws {
        let startedAt = Date(timeIntervalSince1970: 100)
        let recoveredAt = Date(timeIntervalSince1970: 150)
        var queue = UploadQueue()
        let entry = queue.enqueue(
            recordingID: UUID(),
            route: .direct,
            at: startedAt
        )
        try queue.markStarted(entryID: entry.id, at: startedAt)
        let queueStore = TestQueueStore(queue: queue)
        let coordinator = UploadQueueCoordinator(
            manifestStore: TestManifestStore(),
            queueStore: queueStore,
            transport: TestUploadTransport(behavior: .succeed(.uploadedToServer))
        )

        try await coordinator.recoverInterruptedAttempts(at: recoveredAt)

        let saved = await queueStore.snapshot()
        XCTAssertEqual(saved.entries.first?.state, .waiting)
        XCTAssertEqual(saved.entries.first?.nextAttemptAt, recoveredAt)
        XCTAssertEqual(saved.entries.first?.lastFailure?.code, "interrupted_attempt")
    }
}
