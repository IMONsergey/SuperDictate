import Foundation

public enum UploadRunResult: Equatable, Sendable {
    case noWork
    case completed(
        recordingID: UUID,
        acknowledgement: TransferAcknowledgementLevel
    )
    case deferred(
        recordingID: UUID,
        failure: SyncFailure
    )
}

public actor UploadQueueCoordinator {
    private let manifestStore: any RecordingManifestStore
    private let queueStore: any UploadQueueStore
    private let transport: any RecordingUploadTransport
    private let backoff: RetryBackoffPolicy

    public init(
        manifestStore: any RecordingManifestStore,
        queueStore: any UploadQueueStore,
        transport: any RecordingUploadTransport,
        backoff: RetryBackoffPolicy = RetryBackoffPolicy()
    ) {
        self.manifestStore = manifestStore
        self.queueStore = queueStore
        self.transport = transport
        self.backoff = backoff
    }

    @discardableResult
    public func enqueue(
        recordingID: UUID,
        priority: Int = 0,
        route: TransferRoute,
        at date: Date = Date()
    ) async throws -> UploadQueueEntry {
        var queue = try await queueStore.loadQueue()
        let entry = queue.enqueue(
            recordingID: recordingID,
            priority: priority,
            route: route,
            at: date
        )
        try await queueStore.saveQueue(queue)
        return entry
    }

    public func recoverInterruptedAttempts(at date: Date = Date()) async throws {
        var queue = try await queueStore.loadQueue()
        queue.recoverInterruptedAttempts(at: date)
        try await queueStore.saveQueue(queue)
    }

    public func runNext(at date: Date = Date()) async throws -> UploadRunResult {
        var queue = try await queueStore.loadQueue()

        guard let eligible = queue.nextEligible(at: date) else {
            return .noWork
        }

        try queue.markStarted(entryID: eligible.id, at: date)
        try await queueStore.saveQueue(queue)

        guard var manifest = try await manifestStore.load(
            recordingID: eligible.recordingID
        ) else {
            let failure = SyncFailure(
                code: "manifest_missing",
                message: "The local recording manifest is missing.",
                classification: .permanent
            )
            try queue.markFailed(
                entryID: eligible.id,
                failure: failure,
                at: date,
                backoff: backoff
            )
            try await queueStore.saveQueue(queue)
            return .deferred(
                recordingID: eligible.recordingID,
                failure: failure
            )
        }

        do {
            let acknowledgement = try await transport.upload(
                manifest: manifest,
                queueEntry: queue.entries.first(where: { $0.id == eligible.id })
                    ?? eligible
            )

            manifest.advanceAcknowledgement(to: acknowledgement, at: date)
            manifest.localState = localState(for: acknowledgement)
            manifest.lastFailure = nil
            manifest.updatedAt = date
            try await manifestStore.save(manifest)

            try queue.markSucceeded(entryID: eligible.id, at: date)
            try await queueStore.saveQueue(queue)

            return .completed(
                recordingID: eligible.recordingID,
                acknowledgement: acknowledgement
            )
        } catch let failure as SyncFailure {
            try queue.markFailed(
                entryID: eligible.id,
                failure: failure,
                at: date,
                backoff: backoff
            )
            try await queueStore.saveQueue(queue)

            manifest.lastFailure = RecordingFailure(
                code: failure.code,
                message: failure.message,
                retryTarget: failure.classification == .permanent ? .none : .upload
            )
            manifest.localState = .needsAttention
            manifest.updatedAt = date
            try await manifestStore.save(manifest)

            return .deferred(
                recordingID: eligible.recordingID,
                failure: failure
            )
        } catch {
            let failure = SyncFailure(
                code: "transport_error",
                message: String(describing: error),
                classification: .recoverable
            )
            try queue.markFailed(
                entryID: eligible.id,
                failure: failure,
                at: date,
                backoff: backoff
            )
            try await queueStore.saveQueue(queue)

            manifest.lastFailure = RecordingFailure(
                code: failure.code,
                message: failure.message,
                retryTarget: .upload
            )
            manifest.localState = .needsAttention
            manifest.updatedAt = date
            try await manifestStore.save(manifest)

            return .deferred(
                recordingID: eligible.recordingID,
                failure: failure
            )
        }
    }

    private func localState(
        for acknowledgement: TransferAcknowledgementLevel
    ) -> LocalRecordingState {
        switch acknowledgement {
        case .none, .receivedInMemory:
            return .transferring
        case .persistedOnCompanion:
            return .queued
        case .uploadedToServer, .serverManifestCommitted:
            return .uploaded
        case .processingAccepted:
            return .processing
        }
    }
}
