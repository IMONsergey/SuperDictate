import CryptoKit
import Darwin
import Foundation

public enum ChunkWriterError: Error, Equatable, Sendable {
    case insufficientStorage(requiredBytes: Int64, availableBytes: Int64?)
    case packageAlreadyExists(UUID)
    case manifestMissing(UUID)
    case manifestCorrupt(UUID)
    case journalCorrupt(UUID)
    case chunkOpenFailed(String)
    case chunkWriteFailed(String)
    case chunkCloseFailed(String)
    case checksumMismatch(expected: String, actual: String)
    case unsupportedSchema(Int)
    case invalidState(String)
    case fileProtectionUnavailable(String)
    case permissionDenied(String)
    case recoveryRequired(UUID)
    case unrecoverableChunk(String)
}

public enum ChunkChecksumAlgorithm: String, Codable, CaseIterable, Sendable {
    case sha256
}

public struct ChunkWriterPolicy: Codable, Equatable, Sendable {
    public var targetChunkDurationMilliseconds: Int64
    public var maximumChunkDurationMilliseconds: Int64
    public var maximumChunkBytes: Int64
    public var lowStorageSafetyMarginBytes: Int64
    public var flushIntervalBytes: Int
    public var checksumAlgorithm: ChunkChecksumAlgorithm
    public var finalizedChunkExtension: String
    public var temporaryChunkSuffix: String
    public var chunksDirectoryName: String
    public var quarantineDirectoryName: String
    public var journalFileName: String

    public init(
        targetChunkDurationMilliseconds: Int64 = 20_000,
        maximumChunkDurationMilliseconds: Int64 = 30_000,
        maximumChunkBytes: Int64 = 24 * 1_024 * 1_024,
        lowStorageSafetyMarginBytes: Int64 = 32 * 1_024 * 1_024,
        flushIntervalBytes: Int = 256 * 1_024,
        checksumAlgorithm: ChunkChecksumAlgorithm = .sha256,
        finalizedChunkExtension: String = "caf",
        temporaryChunkSuffix: String = "partial",
        chunksDirectoryName: String = "chunks",
        quarantineDirectoryName: String = "quarantine",
        journalFileName: String = "recovery-journal.jsonl"
    ) {
        self.targetChunkDurationMilliseconds = targetChunkDurationMilliseconds
        self.maximumChunkDurationMilliseconds = maximumChunkDurationMilliseconds
        self.maximumChunkBytes = maximumChunkBytes
        self.lowStorageSafetyMarginBytes = lowStorageSafetyMarginBytes
        self.flushIntervalBytes = flushIntervalBytes
        self.checksumAlgorithm = checksumAlgorithm
        self.finalizedChunkExtension = finalizedChunkExtension
        self.temporaryChunkSuffix = temporaryChunkSuffix
        self.chunksDirectoryName = chunksDirectoryName
        self.quarantineDirectoryName = quarantineDirectoryName
        self.journalFileName = journalFileName
    }
}

public enum ChunkRecoveryJournalEventKind: String, Codable, CaseIterable, Sendable {
    case sessionCreated = "session_created"
    case chunkOpening = "chunk_opening"
    case chunkOpened = "chunk_opened"
    case samplesWritten = "samples_written"
    case chunkCloseRequested = "chunk_close_requested"
    case chunkFlushed = "chunk_flushed"
    case chunkClosed = "chunk_closed"
    case checksumComputed = "checksum_computed"
    case manifestCommitStarted = "manifest_commit_started"
    case manifestCommitCompleted = "manifest_commit_completed"
    case recordingStopRequested = "recording_stop_requested"
    case sessionFinalized = "session_finalized"
    case recoveryStarted = "recovery_started"
    case partialChunkQuarantined = "partial_chunk_quarantined"
    case partialChunkRecovered = "partial_chunk_recovered"
    case fatalCorruption = "fatal_corruption"
}

public struct ChunkRecoveryJournalEvent: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let id: UUID
    public let kind: ChunkRecoveryJournalEventKind
    public let recordingID: UUID
    public let chunkID: UUID?
    public let assetID: UUID?
    public let sequence: Int?
    public let byteCount: Int64?
    public let durationMilliseconds: Int64?
    public let checksum: String?
    public let message: String?
    public let createdAt: Date

    public init(
        schemaVersion: Int = ChunkRecoveryJournalEvent.currentSchemaVersion,
        id: UUID = UUID(),
        kind: ChunkRecoveryJournalEventKind,
        recordingID: UUID,
        chunkID: UUID? = nil,
        assetID: UUID? = nil,
        sequence: Int? = nil,
        byteCount: Int64? = nil,
        durationMilliseconds: Int64? = nil,
        checksum: String? = nil,
        message: String? = nil,
        createdAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.kind = kind
        self.recordingID = recordingID
        self.chunkID = chunkID
        self.assetID = assetID
        self.sequence = sequence
        self.byteCount = byteCount
        self.durationMilliseconds = durationMilliseconds
        self.checksum = checksum
        self.message = message
        self.createdAt = createdAt
    }
}

public enum ChunkRecoveryState: String, Codable, CaseIterable, Sendable {
    case valid
    case recovered
    case needsAttention = "needs_attention"
}

public struct ChunkRecoveryResult: Equatable, Sendable {
    public let recordingID: UUID
    public var state: ChunkRecoveryState
    public var recoveredChunkIDs: [UUID]
    public var quarantinedFileNames: [String]
    public var missingChunkIDs: [UUID]
    public var checksumMismatchChunkIDs: [UUID]
    public var corruptJournalTailLineCount: Int
    public var manifestRewritten: Bool

    public init(
        recordingID: UUID,
        state: ChunkRecoveryState = .valid,
        recoveredChunkIDs: [UUID] = [],
        quarantinedFileNames: [String] = [],
        missingChunkIDs: [UUID] = [],
        checksumMismatchChunkIDs: [UUID] = [],
        corruptJournalTailLineCount: Int = 0,
        manifestRewritten: Bool = false
    ) {
        self.recordingID = recordingID
        self.state = state
        self.recoveredChunkIDs = recoveredChunkIDs
        self.quarantinedFileNames = quarantinedFileNames
        self.missingChunkIDs = missingChunkIDs
        self.checksumMismatchChunkIDs = checksumMismatchChunkIDs
        self.corruptJournalTailLineCount = corruptJournalTailLineCount
        self.manifestRewritten = manifestRewritten
    }
}

public struct ChunkFileWriterFaultInjection: Equatable, Sendable {
    public var availableCapacityBytes: Int64?
    public var failNextWrite: Bool
    public var failNextClose: Bool
    public var skipNextManifestCommit: Bool

    public init(
        availableCapacityBytes: Int64? = nil,
        failNextWrite: Bool = false,
        failNextClose: Bool = false,
        skipNextManifestCommit: Bool = false
    ) {
        self.availableCapacityBytes = availableCapacityBytes
        self.failNextWrite = failNextWrite
        self.failNextClose = failNextClose
        self.skipNextManifestCommit = skipNextManifestCommit
    }
}

public actor ChunkFileWriter {
    private struct ActiveChunk {
        let recordingID: UUID
        let chunkID: UUID
        let assetID: UUID
        let sequence: Int
        let temporaryURL: URL
        let finalizedURL: URL
        let openedAt: Date
        let fileDescriptor: Int32
        var byteCount: Int64
        var bytesSinceFlush: Int
    }

    private let rootDirectory: URL
    private let policy: ChunkWriterPolicy
    private let fileManager: FileManager
    private let manifestStore: JSONRecordingManifestStore
    private var activeChunks: [UUID: ActiveChunk] = [:]
    private var faultInjection: ChunkFileWriterFaultInjection

    public init(
        rootDirectory: URL,
        policy: ChunkWriterPolicy = ChunkWriterPolicy(),
        fileManager: FileManager = .default,
        faultInjection: ChunkFileWriterFaultInjection = ChunkFileWriterFaultInjection()
    ) throws {
        self.rootDirectory = rootDirectory
        self.policy = policy
        self.fileManager = fileManager
        self.manifestStore = try JSONRecordingManifestStore(rootDirectory: rootDirectory)
        self.faultInjection = faultInjection
    }

    public func setFaultInjection(_ faultInjection: ChunkFileWriterFaultInjection) {
        self.faultInjection = faultInjection
    }

    public func createSession(
        descriptor: RecordingDescriptor,
        productPolicy: RecordingProductPolicy,
        transferRoute: TransferRoute = .companion,
        at date: Date = Date()
    ) async throws -> LocalRecordingManifest {
        let recordingID = descriptor.clientRecordingID
        let packageURL = await manifestStore.packageURL(recordingID: recordingID)
        if fileManager.fileExists(atPath: packageURL.path) {
            throw ChunkWriterError.packageAlreadyExists(recordingID)
        }

        try createPackageDirectories(for: recordingID)
        let manifest = try LocalRecordingManifest(
            descriptor: descriptor,
            productPolicy: productPolicy,
            localState: .open,
            transferRoute: transferRoute,
            createdAt: date,
            updatedAt: date
        )
        try await manifestStore.save(manifest)
        try appendJournalEvent(
            .sessionCreated,
            recordingID: recordingID,
            createdAt: date
        )
        return manifest
    }

    public func openChunk(
        recordingID: UUID,
        assetID: UUID,
        sequence: Int,
        chunkID: UUID = UUID(),
        at date: Date = Date()
    ) async throws {
        guard sequence >= 0 else {
            throw ChunkWriterError.invalidState("Chunk sequence must not be negative.")
        }

        guard activeChunks[recordingID] == nil else {
            throw ChunkWriterError.invalidState("Recording already has an active chunk.")
        }

        guard let manifest = try await manifestStore.load(recordingID: recordingID) else {
            throw ChunkWriterError.manifestMissing(recordingID)
        }

        guard !manifest.chunks.contains(where: { $0.assetID == assetID && $0.sequence == sequence }) else {
            throw ChunkWriterError.invalidState("Chunk sequence already exists for this asset.")
        }

        try createPackageDirectories(for: recordingID)
        let finalURL = finalizedChunkURL(
            recordingID: recordingID,
            assetID: assetID,
            sequence: sequence,
            chunkID: chunkID
        )
        let temporaryURL = temporaryChunkURL(finalURL: finalURL)
        guard !fileManager.fileExists(atPath: finalURL.path),
              !fileManager.fileExists(atPath: temporaryURL.path) else {
            throw ChunkWriterError.invalidState("Chunk file already exists.")
        }

        try appendJournalEvent(
            .chunkOpening,
            recordingID: recordingID,
            chunkID: chunkID,
            assetID: assetID,
            sequence: sequence,
            createdAt: date
        )

        let fd = Darwin.open(
            temporaryURL.path,
            O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
            privateFileMode
        )
        guard fd >= 0 else {
            throw ChunkWriterError.chunkOpenFailed(currentPOSIXError().localizedDescription)
        }

        do {
            guard Darwin.fchmod(fd, privateFileMode) == 0 else {
                throw ChunkWriterError.permissionDenied(currentPOSIXError().localizedDescription)
            }
            activeChunks[recordingID] = ActiveChunk(
                recordingID: recordingID,
                chunkID: chunkID,
                assetID: assetID,
                sequence: sequence,
                temporaryURL: temporaryURL,
                finalizedURL: finalURL,
                openedAt: date,
                fileDescriptor: fd,
                byteCount: 0,
                bytesSinceFlush: 0
            )
            try appendJournalEvent(
                .chunkOpened,
                recordingID: recordingID,
                chunkID: chunkID,
                assetID: assetID,
                sequence: sequence,
                createdAt: date
            )
        } catch {
            _ = Darwin.close(fd)
            _ = try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }

    public func write(
        _ data: Data,
        to recordingID: UUID,
        at date: Date = Date()
    ) async throws {
        guard !data.isEmpty else { return }
        guard var active = activeChunks[recordingID] else {
            throw ChunkWriterError.invalidState("Recording has no active chunk.")
        }

        try assertCanWrite(bytes: data.count, to: active.temporaryURL)

        if faultInjection.failNextWrite {
            faultInjection.failNextWrite = false
            throw ChunkWriterError.chunkWriteFailed("Injected write failure.")
        }

        do {
            try writeAllData(data, to: active.fileDescriptor)
        } catch {
            throw ChunkWriterError.chunkWriteFailed(error.localizedDescription)
        }

        active.byteCount += Int64(data.count)
        active.bytesSinceFlush += data.count
        if active.bytesSinceFlush >= policy.flushIntervalBytes {
            guard Darwin.fsync(active.fileDescriptor) == 0 else {
                throw ChunkWriterError.chunkWriteFailed(currentPOSIXError().localizedDescription)
            }
            active.bytesSinceFlush = 0
        }
        activeChunks[recordingID] = active

        try appendJournalEvent(
            .samplesWritten,
            recordingID: recordingID,
            chunkID: active.chunkID,
            assetID: active.assetID,
            sequence: active.sequence,
            byteCount: active.byteCount,
            createdAt: date
        )
    }

    public func closeChunk(
        recordingID: UUID,
        durationMilliseconds: Int64,
        at date: Date = Date()
    ) async throws -> AudioChunkDescriptor {
        guard durationMilliseconds >= 0 else {
            throw ChunkWriterError.invalidState("Chunk duration must not be negative.")
        }
        guard var active = activeChunks[recordingID] else {
            throw ChunkWriterError.invalidState("Recording has no active chunk.")
        }

        if faultInjection.failNextClose {
            faultInjection.failNextClose = false
            throw ChunkWriterError.chunkCloseFailed("Injected close failure.")
        }

        try appendJournalEvent(
            .chunkCloseRequested,
            recordingID: recordingID,
            chunkID: active.chunkID,
            assetID: active.assetID,
            sequence: active.sequence,
            byteCount: active.byteCount,
            durationMilliseconds: durationMilliseconds,
            createdAt: date
        )

        guard Darwin.fsync(active.fileDescriptor) == 0 else {
            throw ChunkWriterError.chunkCloseFailed(currentPOSIXError().localizedDescription)
        }
        active.bytesSinceFlush = 0
        activeChunks[recordingID] = active

        try appendJournalEvent(
            .chunkFlushed,
            recordingID: recordingID,
            chunkID: active.chunkID,
            assetID: active.assetID,
            sequence: active.sequence,
            byteCount: active.byteCount,
            durationMilliseconds: durationMilliseconds,
            createdAt: date
        )

        guard Darwin.close(active.fileDescriptor) == 0 else {
            activeChunks[recordingID] = nil
            throw ChunkWriterError.chunkCloseFailed(currentPOSIXError().localizedDescription)
        }
        activeChunks[recordingID] = nil

        do {
            try fileManager.moveItem(at: active.temporaryURL, to: active.finalizedURL)
            try synchronizeDirectory(active.finalizedURL.deletingLastPathComponent())
        } catch {
            throw ChunkWriterError.chunkCloseFailed(error.localizedDescription)
        }

        let checksum = try checksumHex(for: active.finalizedURL)
        let byteCount = try fileByteCount(active.finalizedURL)

        try appendJournalEvent(
            .chunkClosed,
            recordingID: recordingID,
            chunkID: active.chunkID,
            assetID: active.assetID,
            sequence: active.sequence,
            byteCount: byteCount,
            durationMilliseconds: durationMilliseconds,
            checksum: checksum,
            createdAt: date
        )
        try appendJournalEvent(
            .checksumComputed,
            recordingID: recordingID,
            chunkID: active.chunkID,
            assetID: active.assetID,
            sequence: active.sequence,
            byteCount: byteCount,
            durationMilliseconds: durationMilliseconds,
            checksum: checksum,
            createdAt: date
        )

        let descriptor = try AudioChunkDescriptor(
            id: active.chunkID,
            assetID: active.assetID,
            sequence: active.sequence,
            byteCount: byteCount,
            durationMilliseconds: durationMilliseconds,
            checksum: checksum,
            createdAt: date,
            persistenceState: .verified
        )

        if faultInjection.skipNextManifestCommit {
            faultInjection.skipNextManifestCommit = false
            throw ChunkWriterError.recoveryRequired(recordingID)
        }

        try appendJournalEvent(
            .manifestCommitStarted,
            recordingID: recordingID,
            chunkID: descriptor.id,
            assetID: descriptor.assetID,
            sequence: descriptor.sequence,
            byteCount: descriptor.byteCount,
            durationMilliseconds: descriptor.durationMilliseconds,
            checksum: descriptor.checksum,
            createdAt: date
        )

        var manifest = try await requireManifest(recordingID)
        try manifest.appendChunk(descriptor, at: date)
        try await manifestStore.save(manifest)

        try appendJournalEvent(
            .manifestCommitCompleted,
            recordingID: recordingID,
            chunkID: descriptor.id,
            assetID: descriptor.assetID,
            sequence: descriptor.sequence,
            byteCount: descriptor.byteCount,
            durationMilliseconds: descriptor.durationMilliseconds,
            checksum: descriptor.checksum,
            createdAt: date
        )

        return descriptor
    }

    public func finalizeRecording(
        recordingID: UUID,
        endedAt: Date = Date(),
        durationMilliseconds: Int64
    ) async throws -> LocalRecordingManifest {
        guard durationMilliseconds >= 0 else {
            throw ChunkWriterError.invalidState("Recording duration must not be negative.")
        }
        guard activeChunks[recordingID] == nil else {
            throw ChunkWriterError.recoveryRequired(recordingID)
        }

        try appendJournalEvent(
            .recordingStopRequested,
            recordingID: recordingID,
            durationMilliseconds: durationMilliseconds,
            createdAt: endedAt
        )

        var manifest = try await requireManifest(recordingID)
        guard manifest.hasDurableLocalSource else {
            throw ChunkWriterError.recoveryRequired(recordingID)
        }
        manifest.localState = .finalized
        manifest.descriptor.endedAt = endedAt
        manifest.descriptor.durationMilliseconds = durationMilliseconds
        manifest.manifestRevision += 1
        manifest.updatedAt = endedAt
        try await manifestStore.save(manifest)

        try appendJournalEvent(
            .sessionFinalized,
            recordingID: recordingID,
            durationMilliseconds: durationMilliseconds,
            createdAt: endedAt
        )
        return manifest
    }

    public func recover(
        recordingID: UUID,
        at date: Date = Date()
    ) async throws -> ChunkRecoveryResult {
        let packageURL = await manifestStore.packageURL(recordingID: recordingID)
        guard fileManager.fileExists(atPath: packageURL.path) else {
            throw ChunkWriterError.manifestMissing(recordingID)
        }

        let journal = journalStore(recordingID: recordingID)
        let journalSnapshot: JournalSnapshot
        do {
            journalSnapshot = try journal.readEvents()
        } catch ChunkWriterError.unsupportedSchema(let schemaVersion) {
            try? journal.append(
                event(.fatalCorruption, recordingID: recordingID, message: "unsupported_schema_\(schemaVersion)", createdAt: date)
            )
            throw ChunkWriterError.unsupportedSchema(schemaVersion)
        } catch {
            throw error
        }

        try journal.append(event(.recoveryStarted, recordingID: recordingID, createdAt: date))

        var result = ChunkRecoveryResult(
            recordingID: recordingID,
            corruptJournalTailLineCount: journalSnapshot.corruptTailLineCount
        )

        var manifest: LocalRecordingManifest
        do {
            guard let loaded = try await manifestStore.load(recordingID: recordingID) else {
                throw ChunkWriterError.manifestMissing(recordingID)
            }
            manifest = loaded
        } catch ChunkWriterError.manifestMissing {
            throw ChunkWriterError.manifestMissing(recordingID)
        } catch {
            throw ChunkWriterError.manifestCorrupt(recordingID)
        }

        let chunksURL = chunksDirectory(recordingID: recordingID)
        let quarantineURL = quarantineDirectory(recordingID: recordingID)
        try fileManager.createDirectory(at: chunksURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: quarantineURL, withIntermediateDirectories: true)

        var manifestChanged = false
        var needsAttention = false
        var expectedFileNames: Set<String> = []

        for chunk in manifest.chunks {
            let finalURL = finalizedChunkURL(
                recordingID: recordingID,
                assetID: chunk.assetID,
                sequence: chunk.sequence,
                chunkID: chunk.id
            )
            expectedFileNames.insert(finalURL.lastPathComponent)

            guard fileManager.fileExists(atPath: finalURL.path) else {
                result.missingChunkIDs.append(chunk.id)
                needsAttention = true
                continue
            }

            let actualChecksum = try checksumHex(for: finalURL)
            guard actualChecksum == chunk.checksum else {
                result.checksumMismatchChunkIDs.append(chunk.id)
                result.quarantinedFileNames.append(
                    try quarantineFile(finalURL, quarantineDirectory: quarantineURL)
                )
                needsAttention = true
                continue
            }
        }

        let eventsByChunkID = journalSnapshot.events.reduce(into: [UUID: ChunkRecoveryJournalEvent]()) { partial, event in
            guard event.kind == .checksumComputed,
                  let chunkID = event.chunkID else {
                return
            }
            partial[chunkID] = event
        }

        for finalURL in try chunkFileURLs(in: chunksURL, includePartials: false) {
            guard !expectedFileNames.contains(finalURL.lastPathComponent),
                  let identity = parseChunkIdentity(from: finalURL.lastPathComponent) else {
                continue
            }

            let actualChecksum = try checksumHex(for: finalURL)
            if let event = eventsByChunkID[identity.chunkID],
               let expectedChecksum = event.checksum,
               expectedChecksum != actualChecksum {
                result.checksumMismatchChunkIDs.append(identity.chunkID)
                result.quarantinedFileNames.append(
                    try quarantineFile(finalURL, quarantineDirectory: quarantineURL)
                )
                needsAttention = true
                continue
            }

            let event = eventsByChunkID[identity.chunkID]
            let descriptor = try AudioChunkDescriptor(
                id: identity.chunkID,
                assetID: identity.assetID,
                sequence: identity.sequence,
                byteCount: try fileByteCount(finalURL),
                durationMilliseconds: event?.durationMilliseconds ?? 0,
                checksum: actualChecksum,
                createdAt: event?.createdAt ?? date,
                persistenceState: .verified
            )
            try manifest.appendChunk(descriptor, at: date)
            expectedFileNames.insert(finalURL.lastPathComponent)
            result.recoveredChunkIDs.append(identity.chunkID)
            manifestChanged = true
        }

        for partialURL in try chunkFileURLs(in: chunksURL, includePartials: true)
            where partialURL.pathExtension == policy.temporaryChunkSuffix {
            result.quarantinedFileNames.append(
                try quarantineFile(partialURL, quarantineDirectory: quarantineURL)
            )
            needsAttention = true
            try journal.append(
                event(
                    .partialChunkQuarantined,
                    recordingID: recordingID,
                    message: partialURL.lastPathComponent,
                    createdAt: date
                )
            )
        }

        if needsAttention {
            manifest.localState = .needsAttention
            manifest.lastFailure = RecordingFailure(
                code: "recording_recovery_required",
                message: "Recording package has missing, partial, or checksum-mismatched chunks.",
                retryTarget: .upload
            )
            manifest.manifestRevision += 1
            manifest.updatedAt = date
            manifestChanged = true
        }

        if manifestChanged {
            try await manifestStore.save(manifest)
            result.manifestRewritten = true
        }

        if needsAttention {
            result.state = .needsAttention
        } else if !result.recoveredChunkIDs.isEmpty || result.corruptJournalTailLineCount > 0 {
            result.state = .recovered
        } else {
            result.state = .valid
        }

        return result
    }

    public func recoverAll(at date: Date = Date()) async throws -> [ChunkRecoveryResult] {
        let recordingsURL = rootDirectory.appendingPathComponent("recordings", isDirectory: true)
        guard fileManager.fileExists(atPath: recordingsURL.path) else {
            return []
        }

        let packageURLs = try fileManager.contentsOfDirectory(
            at: recordingsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var results: [ChunkRecoveryResult] = []
        for packageURL in packageURLs {
            let values = try packageURL.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true,
                  let recordingID = UUID(uuidString: packageURL.lastPathComponent) else {
                continue
            }
            results.append(try await recover(recordingID: recordingID, at: date))
        }
        return results.sorted { lhs, rhs in
            lhs.recordingID.uuidString < rhs.recordingID.uuidString
        }
    }

    public func journalEvents(recordingID: UUID) throws -> [ChunkRecoveryJournalEvent] {
        try journalStore(recordingID: recordingID).readEvents().events
    }

    public func packageURL(recordingID: UUID) async -> URL {
        await manifestStore.packageURL(recordingID: recordingID)
    }

    public func finalizedChunkURL(
        recordingID: UUID,
        assetID: UUID,
        sequence: Int,
        chunkID: UUID
    ) -> URL {
        chunksDirectory(recordingID: recordingID)
            .appendingPathComponent(
                chunkFileName(assetID: assetID, sequence: sequence, chunkID: chunkID)
            )
    }

    private func requireManifest(_ recordingID: UUID) async throws -> LocalRecordingManifest {
        guard let manifest = try await manifestStore.load(recordingID: recordingID) else {
            throw ChunkWriterError.manifestMissing(recordingID)
        }
        return manifest
    }

    private func createPackageDirectories(for recordingID: UUID) throws {
        try fileManager.createDirectory(
            at: chunksDirectory(recordingID: recordingID),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: quarantineDirectory(recordingID: recordingID),
            withIntermediateDirectories: true
        )
    }

    private func appendJournalEvent(
        _ kind: ChunkRecoveryJournalEventKind,
        recordingID: UUID,
        chunkID: UUID? = nil,
        assetID: UUID? = nil,
        sequence: Int? = nil,
        byteCount: Int64? = nil,
        durationMilliseconds: Int64? = nil,
        checksum: String? = nil,
        message: String? = nil,
        createdAt: Date
    ) throws {
        try journalStore(recordingID: recordingID).append(
            event(
                kind,
                recordingID: recordingID,
                chunkID: chunkID,
                assetID: assetID,
                sequence: sequence,
                byteCount: byteCount,
                durationMilliseconds: durationMilliseconds,
                checksum: checksum,
                message: message,
                createdAt: createdAt
            )
        )
    }

    private func event(
        _ kind: ChunkRecoveryJournalEventKind,
        recordingID: UUID,
        chunkID: UUID? = nil,
        assetID: UUID? = nil,
        sequence: Int? = nil,
        byteCount: Int64? = nil,
        durationMilliseconds: Int64? = nil,
        checksum: String? = nil,
        message: String? = nil,
        createdAt: Date
    ) -> ChunkRecoveryJournalEvent {
        ChunkRecoveryJournalEvent(
            kind: kind,
            recordingID: recordingID,
            chunkID: chunkID,
            assetID: assetID,
            sequence: sequence,
            byteCount: byteCount,
            durationMilliseconds: durationMilliseconds,
            checksum: checksum,
            message: message,
            createdAt: createdAt
        )
    }

    private func assertCanWrite(bytes: Int, to url: URL) throws {
        let required = Int64(bytes) + policy.lowStorageSafetyMarginBytes
        let available = faultInjection.availableCapacityBytes ?? availableCapacityBytes(containing: url)
        if let available, available < required {
            throw ChunkWriterError.insufficientStorage(
                requiredBytes: required,
                availableBytes: available
            )
        }
    }

    private func availableCapacityBytes(containing url: URL) -> Int64? {
        try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage
    }

    private func journalStore(recordingID: UUID) -> ChunkRecoveryJournalStore {
        ChunkRecoveryJournalStore(
            journalURL: packageDirectory(recordingID: recordingID)
                .appendingPathComponent(policy.journalFileName),
            fileManager: fileManager
        )
    }

    private func packageDirectory(recordingID: UUID) -> URL {
        rootDirectory
            .appendingPathComponent("recordings", isDirectory: true)
            .appendingPathComponent(recordingID.uuidString.lowercased(), isDirectory: true)
    }

    private func chunksDirectory(recordingID: UUID) -> URL {
        packageDirectory(recordingID: recordingID)
            .appendingPathComponent(policy.chunksDirectoryName, isDirectory: true)
    }

    private func quarantineDirectory(recordingID: UUID) -> URL {
        packageDirectory(recordingID: recordingID)
            .appendingPathComponent(policy.quarantineDirectoryName, isDirectory: true)
    }

    private func chunkFileName(assetID: UUID, sequence: Int, chunkID: UUID) -> String {
        let normalizedExtension = policy.finalizedChunkExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return "\(assetID.uuidString.lowercased())__\(String(format: "%06d", sequence))__\(chunkID.uuidString.lowercased()).\(normalizedExtension)"
    }

    private func temporaryChunkURL(finalURL: URL) -> URL {
        finalURL.appendingPathExtension(policy.temporaryChunkSuffix)
    }

    private func parseChunkIdentity(from fileName: String) -> ChunkIdentity? {
        guard !fileName.hasSuffix(".\(policy.temporaryChunkSuffix)") else {
            return nil
        }
        let normalizedExtension = ".\(policy.finalizedChunkExtension.trimmingCharacters(in: CharacterSet(charactersIn: ".")))"
        guard fileName.hasSuffix(normalizedExtension) else {
            return nil
        }
        let stem = String(fileName.dropLast(normalizedExtension.count))
        let parts = stem.components(separatedBy: "__")
        guard parts.count == 3,
              let assetID = UUID(uuidString: parts[0]),
              let sequence = Int(parts[1]),
              let chunkID = UUID(uuidString: parts[2]) else {
            return nil
        }
        return ChunkIdentity(assetID: assetID, sequence: sequence, chunkID: chunkID)
    }

    private func chunkFileURLs(in directory: URL, includePartials: Bool) throws -> [URL] {
        guard fileManager.fileExists(atPath: directory.path) else {
            return []
        }
        return try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        .filter { url in
            let isPartial = url.pathExtension == policy.temporaryChunkSuffix
            return includePartials ? isPartial : !isPartial
        }
        .sorted { lhs, rhs in
            lhs.lastPathComponent < rhs.lastPathComponent
        }
    }

    private func quarantineFile(_ url: URL, quarantineDirectory: URL) throws -> String {
        let destination = uniqueQuarantineURL(for: url, in: quarantineDirectory)
        try fileManager.moveItem(at: url, to: destination)
        try synchronizeDirectory(quarantineDirectory)
        return destination.lastPathComponent
    }

    private func uniqueQuarantineURL(for url: URL, in directory: URL) -> URL {
        let baseName = "\(url.lastPathComponent).quarantine"
        var destination = directory.appendingPathComponent(baseName)
        var attempt = 1
        while fileManager.fileExists(atPath: destination.path) {
            destination = directory.appendingPathComponent("\(baseName).\(attempt)")
            attempt += 1
        }
        return destination
    }

    private func checksumHex(for url: URL) throws -> String {
        switch policy.checksumAlgorithm {
        case .sha256:
            let data = try Data(contentsOf: url)
            let digest = SHA256.hash(data: data)
            let hex = digest.map { String(format: "%02x", $0) }.joined()
            return "sha256:\(hex)"
        }
    }

    private func fileByteCount(_ url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values.fileSize ?? 0)
    }

    private func synchronizeDirectory(_ url: URL) throws {
        let fd = Darwin.open(url.path, O_RDONLY | O_CLOEXEC)
        guard fd >= 0 else {
            throw ChunkWriterError.chunkCloseFailed(currentPOSIXError().localizedDescription)
        }
        defer { _ = Darwin.close(fd) }
        guard Darwin.fsync(fd) == 0 else {
            throw ChunkWriterError.chunkCloseFailed(currentPOSIXError().localizedDescription)
        }
    }
}

private struct ChunkIdentity {
    let assetID: UUID
    let sequence: Int
    let chunkID: UUID
}

private struct JournalSnapshot {
    var events: [ChunkRecoveryJournalEvent]
    var corruptTailLineCount: Int
}

private struct ChunkRecoveryJournalStore {
    let journalURL: URL
    let fileManager: FileManager

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }

    func append(_ event: ChunkRecoveryJournalEvent) throws {
        try fileManager.createDirectory(
            at: journalURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var data = Data()
        if fileManager.fileExists(atPath: journalURL.path),
           let lastByte = try Data(contentsOf: journalURL).last,
           lastByte != UInt8(ascii: "\n") {
            data.append(UInt8(ascii: "\n"))
        }
        data.append(try encoder.encode(event))
        data.append(UInt8(ascii: "\n"))

        let fd = Darwin.open(
            journalURL.path,
            O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC | O_NOFOLLOW,
            privateFileMode
        )
        guard fd >= 0 else {
            throw ChunkWriterError.journalCorrupt(event.recordingID)
        }
        defer { _ = Darwin.close(fd) }

        guard Darwin.fchmod(fd, privateFileMode) == 0 else {
            throw ChunkWriterError.permissionDenied(currentPOSIXError().localizedDescription)
        }
        try writeAllData(data, to: fd)
        guard Darwin.fsync(fd) == 0 else {
            throw ChunkWriterError.journalCorrupt(event.recordingID)
        }
    }

    func readEvents() throws -> JournalSnapshot {
        guard fileManager.fileExists(atPath: journalURL.path) else {
            return JournalSnapshot(events: [], corruptTailLineCount: 0)
        }

        let data = try Data(contentsOf: journalURL)
        guard !data.isEmpty else {
            return JournalSnapshot(events: [], corruptTailLineCount: 0)
        }

        let lines = String(decoding: data, as: UTF8.self)
            .split(separator: "\n", omittingEmptySubsequences: false)
        var events: [ChunkRecoveryJournalEvent] = []
        var corruptTailLineCount = 0

        for (index, line) in lines.enumerated() {
            guard !line.isEmpty else { continue }
            do {
                let event = try decoder.decode(
                    ChunkRecoveryJournalEvent.self,
                    from: Data(line.utf8)
                )
                guard event.schemaVersion == ChunkRecoveryJournalEvent.currentSchemaVersion else {
                    throw ChunkWriterError.unsupportedSchema(event.schemaVersion)
                }
                events.append(event)
            } catch ChunkWriterError.unsupportedSchema(let schemaVersion) {
                throw ChunkWriterError.unsupportedSchema(schemaVersion)
            } catch {
                if index == lines.count - 1 {
                    corruptTailLineCount += 1
                    break
                }
                throw ChunkWriterError.journalCorrupt(events.last?.recordingID ?? UUID())
            }
        }

        return JournalSnapshot(
            events: events,
            corruptTailLineCount: corruptTailLineCount
        )
    }
}

private let privateFileMode = mode_t(S_IRUSR | S_IWUSR)

private func writeAllData(_ data: Data, to fd: Int32) throws {
    try data.withUnsafeBytes { rawBuffer in
        guard let baseAddress = rawBuffer.baseAddress else { return }
        var written = 0
        while written < rawBuffer.count {
            let result = Darwin.write(
                fd,
                baseAddress.advanced(by: written),
                rawBuffer.count - written
            )
            if result < 0 {
                if errno == EINTR { continue }
                throw currentPOSIXError()
            }
            guard result > 0 else {
                throw ChunkWriterError.chunkWriteFailed("write returned zero bytes")
            }
            written += result
        }
    }
}

private func currentPOSIXError() -> POSIXError {
    POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
}
