import Foundation

public enum SyncValidationError: Error, Equatable, Sendable {
    case negativeSequence
    case negativeByteCount
    case negativeDuration
    case emptyChecksum
    case invalidManifestRevision
    case missingChunk
    case invalidQueueTransition
}

public enum LocalRecordingState: String, Codable, CaseIterable, Sendable {
    case open
    case finalizing
    case finalized
    case queued
    case transferring
    case uploaded
    case processing
    case ready
    case needsAttention = "needs_attention"
    case deletionPending = "deletion_pending"
    case deleted
}

public enum TransferRoute: String, Codable, CaseIterable, Sendable {
    case companion
    case direct
}

public enum TransferAcknowledgementLevel: Int, Codable, CaseIterable, Comparable, Sendable {
    case none = 0
    case receivedInMemory = 1
    case persistedOnCompanion = 2
    case uploadedToServer = 3
    case serverManifestCommitted = 4
    case processingAccepted = 5

    public static func < (
        lhs: TransferAcknowledgementLevel,
        rhs: TransferAcknowledgementLevel
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum ChunkPersistenceState: String, Codable, CaseIterable, Sendable {
    case writing
    case closed
    case verified
    case transferred
}

public struct AudioChunkDescriptor: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let assetID: UUID
    public let sequence: Int
    public let byteCount: Int64
    public let durationMilliseconds: Int64
    public let checksum: String
    public let createdAt: Date
    public var persistenceState: ChunkPersistenceState

    public init(
        id: UUID = UUID(),
        assetID: UUID,
        sequence: Int,
        byteCount: Int64,
        durationMilliseconds: Int64,
        checksum: String,
        createdAt: Date = Date(),
        persistenceState: ChunkPersistenceState = .closed
    ) throws {
        guard sequence >= 0 else {
            throw SyncValidationError.negativeSequence
        }

        guard byteCount >= 0 else {
            throw SyncValidationError.negativeByteCount
        }

        guard durationMilliseconds >= 0 else {
            throw SyncValidationError.negativeDuration
        }

        guard !checksum.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SyncValidationError.emptyChecksum
        }

        self.id = id
        self.assetID = assetID
        self.sequence = sequence
        self.byteCount = byteCount
        self.durationMilliseconds = durationMilliseconds
        self.checksum = checksum
        self.createdAt = createdAt
        self.persistenceState = persistenceState
    }
}

public struct LocalRecordingManifest: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var descriptor: RecordingDescriptor
    public var productPolicy: RecordingProductPolicy
    public var localState: LocalRecordingState
    public var manifestRevision: Int
    public var chunks: [AudioChunkDescriptor]
    public var markers: [RecordingMarker]
    public var transferRoute: TransferRoute
    public var acknowledgementLevel: TransferAcknowledgementLevel
    public var serverRecordingID: UUID?
    public var lastFailure: RecordingFailure?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID? = nil,
        descriptor: RecordingDescriptor,
        productPolicy: RecordingProductPolicy,
        localState: LocalRecordingState = .open,
        manifestRevision: Int = 1,
        chunks: [AudioChunkDescriptor] = [],
        markers: [RecordingMarker] = [],
        transferRoute: TransferRoute = .companion,
        acknowledgementLevel: TransferAcknowledgementLevel = .none,
        serverRecordingID: UUID? = nil,
        lastFailure: RecordingFailure? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) throws {
        guard manifestRevision > 0 else {
            throw SyncValidationError.invalidManifestRevision
        }

        self.id = id ?? descriptor.clientRecordingID
        self.descriptor = descriptor
        self.productPolicy = productPolicy
        self.localState = localState
        self.manifestRevision = manifestRevision
        self.chunks = chunks.sorted { lhs, rhs in
            if lhs.assetID == rhs.assetID {
                return lhs.sequence < rhs.sequence
            }
            return lhs.assetID.uuidString < rhs.assetID.uuidString
        }
        self.markers = markers
        self.transferRoute = transferRoute
        self.acknowledgementLevel = acknowledgementLevel
        self.serverRecordingID = serverRecordingID
        self.lastFailure = lastFailure
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var totalByteCount: Int64 {
        chunks.reduce(0) { partial, chunk in
            partial + chunk.byteCount
        }
    }

    public var totalChunkDurationMilliseconds: Int64 {
        chunks.reduce(0) { partial, chunk in
            partial + chunk.durationMilliseconds
        }
    }

    public var hasDurableLocalSource: Bool {
        !chunks.isEmpty && chunks.allSatisfy { chunk in
            chunk.persistenceState == .closed
                || chunk.persistenceState == .verified
                || chunk.persistenceState == .transferred
        }
    }

    public mutating func appendChunk(_ chunk: AudioChunkDescriptor, at date: Date = Date()) throws {
        if chunks.contains(where: { $0.id == chunk.id }) {
            return
        }

        let hasSequenceConflict = chunks.contains { existing in
            existing.assetID == chunk.assetID && existing.sequence == chunk.sequence
        }

        guard !hasSequenceConflict else {
            throw SyncValidationError.invalidQueueTransition
        }

        chunks.append(chunk)
        chunks.sort { lhs, rhs in
            if lhs.assetID == rhs.assetID {
                return lhs.sequence < rhs.sequence
            }
            return lhs.assetID.uuidString < rhs.assetID.uuidString
        }
        manifestRevision += 1
        updatedAt = date
    }

    public mutating func advanceAcknowledgement(
        to level: TransferAcknowledgementLevel,
        at date: Date = Date()
    ) {
        guard level > acknowledgementLevel else {
            return
        }

        acknowledgementLevel = level
        manifestRevision += 1
        updatedAt = date
    }
}

public enum SyncFailureClassification: String, Codable, CaseIterable, Sendable {
    case recoverable
    case requiresUserAction = "requires_user_action"
    case permanent
}

public struct SyncFailure: Error, Codable, Equatable, Sendable {
    public let code: String
    public let message: String
    public let classification: SyncFailureClassification

    public init(
        code: String,
        message: String,
        classification: SyncFailureClassification
    ) {
        self.code = code
        self.message = message
        self.classification = classification
    }
}

public enum UploadQueueEntryState: String, Codable, CaseIterable, Sendable {
    case waiting
    case inFlight = "in_flight"
    case blockedUserAction = "blocked_user_action"
    case succeeded
    case failedPermanent = "failed_permanent"
}

public struct UploadQueueEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let recordingID: UUID
    public let idempotencyKey: String
    public var priority: Int
    public var route: TransferRoute
    public var state: UploadQueueEntryState
    public var attemptCount: Int
    public var nextAttemptAt: Date
    public var lastFailure: SyncFailure?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        recordingID: UUID,
        idempotencyKey: String? = nil,
        priority: Int = 0,
        route: TransferRoute,
        state: UploadQueueEntryState = .waiting,
        attemptCount: Int = 0,
        nextAttemptAt: Date = Date(),
        lastFailure: SyncFailure? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.recordingID = recordingID
        self.idempotencyKey = idempotencyKey
            ?? "recording:\(recordingID.uuidString.lowercased()):upload"
        self.priority = priority
        self.route = route
        self.state = state
        self.attemptCount = max(0, attemptCount)
        self.nextAttemptAt = nextAttemptAt
        self.lastFailure = lastFailure
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var isTerminal: Bool {
        state == .succeeded || state == .failedPermanent
    }
}

public struct RetryBackoffPolicy: Codable, Equatable, Sendable {
    public let initialDelay: TimeInterval
    public let multiplier: Double
    public let maximumDelay: TimeInterval

    public init(
        initialDelay: TimeInterval = 5,
        multiplier: Double = 2,
        maximumDelay: TimeInterval = 3_600
    ) {
        self.initialDelay = max(0, initialDelay)
        self.multiplier = max(1, multiplier)
        self.maximumDelay = max(self.initialDelay, maximumDelay)
    }

    public func baseDelay(afterAttempt attemptCount: Int) -> TimeInterval {
        guard attemptCount > 0 else {
            return 0
        }

        let exponential = initialDelay * pow(multiplier, Double(attemptCount - 1))
        return min(maximumDelay, exponential)
    }
}

public struct UploadQueue: Codable, Equatable, Sendable {
    public private(set) var entries: [UploadQueueEntry]

    public init(entries: [UploadQueueEntry] = []) {
        self.entries = entries
    }

    @discardableResult
    public mutating func enqueue(
        recordingID: UUID,
        priority: Int = 0,
        route: TransferRoute,
        at date: Date = Date()
    ) -> UploadQueueEntry {
        if let existing = entries.first(where: { entry in
            entry.recordingID == recordingID && !entry.isTerminal
        }) {
            return existing
        }

        if let succeeded = entries.first(where: { entry in
            entry.recordingID == recordingID && entry.state == .succeeded
        }) {
            return succeeded
        }

        let entry = UploadQueueEntry(
            recordingID: recordingID,
            priority: priority,
            route: route,
            nextAttemptAt: date,
            createdAt: date,
            updatedAt: date
        )
        entries.append(entry)
        return entry
    }

    public func nextEligible(at date: Date = Date()) -> UploadQueueEntry? {
        entries
            .filter { entry in
                entry.state == .waiting && entry.nextAttemptAt <= date
            }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority > rhs.priority
                }
                return lhs.createdAt < rhs.createdAt
            }
            .first
    }

    public mutating func markStarted(entryID: UUID, at date: Date = Date()) throws {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else {
            throw SyncValidationError.invalidQueueTransition
        }

        guard entries[index].state == .waiting else {
            throw SyncValidationError.invalidQueueTransition
        }

        entries[index].state = .inFlight
        entries[index].attemptCount += 1
        entries[index].lastFailure = nil
        entries[index].updatedAt = date
    }

    public mutating func markSucceeded(entryID: UUID, at date: Date = Date()) throws {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else {
            throw SyncValidationError.invalidQueueTransition
        }

        guard entries[index].state == .inFlight else {
            throw SyncValidationError.invalidQueueTransition
        }

        entries[index].state = .succeeded
        entries[index].lastFailure = nil
        entries[index].updatedAt = date
    }

    public mutating func markFailed(
        entryID: UUID,
        failure: SyncFailure,
        at date: Date = Date(),
        backoff: RetryBackoffPolicy = RetryBackoffPolicy()
    ) throws {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else {
            throw SyncValidationError.invalidQueueTransition
        }

        guard entries[index].state == .inFlight else {
            throw SyncValidationError.invalidQueueTransition
        }

        entries[index].lastFailure = failure
        entries[index].updatedAt = date

        switch failure.classification {
        case .recoverable:
            entries[index].state = .waiting
            let delay = backoff.baseDelay(afterAttempt: entries[index].attemptCount)
            entries[index].nextAttemptAt = date.addingTimeInterval(delay)

        case .requiresUserAction:
            entries[index].state = .blockedUserAction

        case .permanent:
            entries[index].state = .failedPermanent
        }
    }

    public mutating func unblock(entryID: UUID, at date: Date = Date()) throws {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else {
            throw SyncValidationError.invalidQueueTransition
        }

        guard entries[index].state == .blockedUserAction else {
            throw SyncValidationError.invalidQueueTransition
        }

        entries[index].state = .waiting
        entries[index].nextAttemptAt = date
        entries[index].lastFailure = nil
        entries[index].updatedAt = date
    }

    public mutating func recoverInterruptedAttempts(at date: Date = Date()) {
        for index in entries.indices where entries[index].state == .inFlight {
            entries[index].state = .waiting
            entries[index].nextAttemptAt = date
            entries[index].lastFailure = SyncFailure(
                code: "interrupted_attempt",
                message: "The previous transfer attempt ended before acknowledgement.",
                classification: .recoverable
            )
            entries[index].updatedAt = date
        }
    }
}

public protocol RecordingManifestStore: Sendable {
    func load(recordingID: UUID) async throws -> LocalRecordingManifest?
    func save(_ manifest: LocalRecordingManifest) async throws
    func listPendingTransfer() async throws -> [LocalRecordingManifest]
    func removeLocalSource(recordingID: UUID) async throws
}

public protocol UploadQueueStore: Sendable {
    func loadQueue() async throws -> UploadQueue
    func saveQueue(_ queue: UploadQueue) async throws
}

public protocol RecordingUploadTransport: Sendable {
    func upload(
        manifest: LocalRecordingManifest,
        queueEntry: UploadQueueEntry
    ) async throws -> TransferAcknowledgementLevel
}
