import CryptoKit
import Darwin
import Foundation

public enum SuperDictateMemoryRecoveryState: String, Codable, Sendable {
    case valid
    case recovered
    case needsAttention = "needs_attention"
}

public struct SuperDictateMemoryRecoveryResult: Equatable, Sendable {
    public let recordingID: UUID
    public var state: SuperDictateMemoryRecoveryState
    public var recoveredChunkIDs: [UUID]
    public var missingChunkIDs: [UUID]
    public var checksumMismatchChunkIDs: [UUID]
    public var journalConflictChunkIDs: [UUID]
    public var quarantinedFileNames: [String]
    public var ignoredPartialJournalTail: Bool

    public init(
        recordingID: UUID,
        state: SuperDictateMemoryRecoveryState = .valid,
        recoveredChunkIDs: [UUID] = [],
        missingChunkIDs: [UUID] = [],
        checksumMismatchChunkIDs: [UUID] = [],
        journalConflictChunkIDs: [UUID] = [],
        quarantinedFileNames: [String] = [],
        ignoredPartialJournalTail: Bool = false
    ) {
        self.recordingID = recordingID
        self.state = state
        self.recoveredChunkIDs = recoveredChunkIDs
        self.missingChunkIDs = missingChunkIDs
        self.checksumMismatchChunkIDs = checksumMismatchChunkIDs
        self.journalConflictChunkIDs = journalConflictChunkIDs
        self.quarantinedFileNames = quarantinedFileNames
        self.ignoredPartialJournalTail = ignoredPartialJournalTail
    }
}

/// Batch recovery never lets one corrupt UUID-named package hide the health of
/// the rest of the Library. Unsafe/unreadable package candidates are reported by
/// stable recording ID without leaking private filesystem paths.
public struct SuperDictateMemoryRecoveryBatchResult: Equatable, Sendable {
    public var results: [SuperDictateMemoryRecoveryResult]
    public var failedRecordingIDs: [UUID]

    public init(
        results: [SuperDictateMemoryRecoveryResult] = [],
        failedRecordingIDs: [UUID] = []
    ) {
        self.results = results
        self.failedRecordingIDs = failedRecordingIDs
    }
}

public enum SuperDictateMemoryRecoveryError: Error, Equatable, Sendable {
    case unsafeFileType(String)
    case invalidContainer(String)
    case byteLengthMismatch(path: String, expected: Int64, actual: Int64)
    case fileTooLarge(path: String, actual: Int64, maximum: Int64)
    case committedChecksumMismatch(chunkID: UUID)
    case fileOperationFailed(String)
    case posix(Int32)
}

/// Conservative integrity recovery for authoritative Memory Capture packages.
///
/// Source bytes are never reconstructed from guesses:
/// - manifest-referenced chunks must still match CAF magic, byte length and SHA;
/// - `.partial` files are unfinished and are quarantined, never indexed;
/// - finalized orphans require durable journal metadata;
/// - committed orphans additionally require the journal's original SHA;
/// - undocumented/conflicting source is quarantined, not deleted;
/// - verified orphan descriptors can be reattached to a ready package only via
///   the Core-internal integrity mutation; ordinary capture remains terminal.
public actor SuperDictateMemoryPackageRecovery {
    private let store: JSONSuperDictateMemoryPackageStore
    private let fileManager: FileManager
    private let policy: SuperDictateMemoryChunkPolicy

    public init(
        store: JSONSuperDictateMemoryPackageStore,
        policy: SuperDictateMemoryChunkPolicy = SuperDictateMemoryChunkPolicy(),
        fileManager: FileManager = .default
    ) {
        self.store = store
        self.policy = policy
        self.fileManager = fileManager
    }

    public func recover(
        recordingID: UUID
    ) async throws -> SuperDictateMemoryRecoveryResult {
        guard var manifest = try await store.loadManifest(recordingID: recordingID) else {
            throw SuperDictateMemoryPackageStoreError.packageMissing(recordingID)
        }
        let preexistingAttention = manifest.state == .needsAttention
        let journal = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        let latestJournalByChunkID = journal.latestEventByChunkID
        let latestJournalByPath = journal.events.reduce(into: [String: SuperDictateMemoryRecoveryEvent]()) {
            $0[$1.relativePath] = $1
        }

        var result = SuperDictateMemoryRecoveryResult(
            recordingID: recordingID,
            ignoredPartialJournalTail: journal.ignoredPartialTailLine
        )
        var integrityIssueDetected = false

        let packageURL = await store.packageURL(recordingID: recordingID)
        let quarantineURL = await store.quarantineDirectory(recordingID: recordingID)
        try validateDirectoryNoFollow(quarantineURL, normalizePermissions: true)

        var referencedRelativePaths: Set<String> = []
        var observedRecoveryRelativePaths: Set<String> = []

        // 1. Verify every source object already claimed by the authoritative
        // manifest. A manifest is never trusted without checking its bytes.
        for chunk in manifest.chunks {
            referencedRelativePaths.insert(chunk.relativePath)
            let sourceURL = packageURL.appendingPathComponent(
                chunk.relativePath,
                isDirectory: false
            )

            guard try pathEntryExists(sourceURL) else {
                appendUnique(chunk.id, to: &result.missingChunkIDs)
                integrityIssueDetected = true
                continue
            }
            observedRecoveryRelativePaths.insert(chunk.relativePath)

            do {
                let inspection = try inspectCAF(sourceURL)
                guard inspection.byteLength == chunk.byteLength else {
                    throw SuperDictateMemoryRecoveryError.byteLengthMismatch(
                        path: chunk.relativePath,
                        expected: chunk.byteLength,
                        actual: inspection.byteLength
                    )
                }
                guard inspection.sha256 == chunk.sha256 else {
                    appendUnique(chunk.id, to: &result.checksumMismatchChunkIDs)
                    result.quarantinedFileNames.append(
                        try quarantine(sourceURL, into: quarantineURL)
                    )
                    integrityIssueDetected = true
                    continue
                }

                if let event = latestJournalByChunkID[chunk.id] {
                    guard journalEvent(event, matches: chunk) else {
                        appendUnique(chunk.id, to: &result.journalConflictChunkIDs)
                        integrityIssueDetected = true
                        continue
                    }

                    switch event.kind {
                    case .chunkPrepared:
                        // Crash after the manifest save but before the advisory
                        // committed event. Close the journal using the manifest's
                        // independently verified checksum.
                        do {
                            try await store.appendRecoveryEvent(
                                committedEvent(from: event, sha256: chunk.sha256)
                            )
                        } catch {
                            appendUnique(chunk.id, to: &result.journalConflictChunkIDs)
                            integrityIssueDetected = true
                        }
                    case .chunkCommitted:
                        guard event.sha256 == chunk.sha256 else {
                            appendUnique(chunk.id, to: &result.journalConflictChunkIDs)
                            integrityIssueDetected = true
                            continue
                        }
                    }
                }
            } catch {
                // Preserve suspicious bytes for explicit recovery/forensics.
                if try pathEntryExists(sourceURL) {
                    result.quarantinedFileNames.append(
                        try quarantine(sourceURL, into: quarantineURL)
                    )
                }
                integrityIssueDetected = true
            }
        }

        // 2. Classify source files not currently referenced by the manifest.
        // This is where crash-orphans are either proven and reattached or isolated.
        let partialExtension = policy.partialSuffix
        let partialPathSuffix = ".\(partialExtension)"

        for source in SuperDictateMemoryAudioSource.allCases {
            let sourceDirectory = await store.audioDirectory(
                recordingID: recordingID,
                source: source
            )
            for sourceURL in try sourceFiles(sourceDirectory) {
                let relativePath = "audio/\(source.rawValue)/\(sourceURL.lastPathComponent)"

                if sourceURL.pathExtension == partialExtension {
                    let finalRelativePath = relativePath.hasSuffix(partialPathSuffix)
                        ? String(relativePath.dropLast(partialPathSuffix.count))
                        : relativePath
                    observedRecoveryRelativePaths.insert(finalRelativePath)
                } else {
                    observedRecoveryRelativePaths.insert(relativePath)
                }

                if referencedRelativePaths.contains(relativePath) {
                    continue
                }

                if sourceURL.pathExtension == partialExtension {
                    result.quarantinedFileNames.append(
                        try quarantine(sourceURL, into: quarantineURL)
                    )
                    integrityIssueDetected = true
                    continue
                }

                guard sourceURL.pathExtension == SuperDictateMemoryAudioContainer.caf.rawValue else {
                    result.quarantinedFileNames.append(
                        try quarantine(sourceURL, into: quarantineURL)
                    )
                    integrityIssueDetected = true
                    continue
                }

                guard let event = latestJournalByPath[relativePath],
                      event.recordingID == recordingID,
                      event.source == source else {
                    result.quarantinedFileNames.append(
                        try quarantine(sourceURL, into: quarantineURL)
                    )
                    integrityIssueDetected = true
                    continue
                }

                do {
                    let inspection = try inspectCAF(sourceURL)
                    guard inspection.byteLength == event.byteLength else {
                        throw SuperDictateMemoryRecoveryError.byteLengthMismatch(
                            path: relativePath,
                            expected: event.byteLength,
                            actual: inspection.byteLength
                        )
                    }

                    if event.kind == .chunkCommitted {
                        guard event.sha256 == inspection.sha256 else {
                            appendUnique(event.chunkID, to: &result.checksumMismatchChunkIDs)
                            throw SuperDictateMemoryRecoveryError.committedChecksumMismatch(
                                chunkID: event.chunkID
                            )
                        }
                    }

                    let descriptor = try SuperDictateMemoryAudioChunk(
                        id: event.chunkID,
                        source: event.source,
                        sequence: event.sequence,
                        relativePath: event.relativePath,
                        sessionStartMilliseconds: event.sessionStartMilliseconds,
                        sessionEndMilliseconds: event.sessionEndMilliseconds,
                        container: event.container,
                        codec: event.codec,
                        sampleRate: event.sampleRate,
                        channelCount: event.channelCount,
                        byteLength: inspection.byteLength,
                        sha256: inspection.sha256
                    )

                    manifest = try await store.reattachVerifiedChunk(
                        recordingID: recordingID,
                        chunk: descriptor
                    )
                    referencedRelativePaths.insert(relativePath)
                    appendUnique(event.chunkID, to: &result.recoveredChunkIDs)

                    if event.kind == .chunkPrepared {
                        do {
                            try await store.appendRecoveryEvent(
                                committedEvent(from: event, sha256: inspection.sha256)
                            )
                        } catch {
                            appendUnique(event.chunkID, to: &result.journalConflictChunkIDs)
                            integrityIssueDetected = true
                        }
                    }
                } catch {
                    if try pathEntryExists(sourceURL) {
                        result.quarantinedFileNames.append(
                            try quarantine(sourceURL, into: quarantineURL)
                        )
                    }
                    integrityIssueDetected = true
                }
            }
        }

        // 3. Journal evidence that cannot be accounted for by a manifest row,
        // partial or final source means durable source bytes disappeared.
        for event in latestJournalByPath.values {
            guard !observedRecoveryRelativePaths.contains(event.relativePath) else {
                continue
            }
            appendUnique(event.chunkID, to: &result.missingChunkIDs)
            integrityIssueDetected = true
        }

        result.missingChunkIDs.sort { $0.uuidString < $1.uuidString }
        result.checksumMismatchChunkIDs.sort { $0.uuidString < $1.uuidString }
        result.journalConflictChunkIDs.sort { $0.uuidString < $1.uuidString }
        result.recoveredChunkIDs.sort { $0.uuidString < $1.uuidString }
        result.quarantinedFileNames.sort()

        if integrityIssueDetected {
            _ = try await store.markIntegrityNeedsAttention(
                recordingID: recordingID,
                message: recoveryIssueMessage(result)
            )
            result.state = .needsAttention
        } else if preexistingAttention {
            // Scanner found no new physical problem; preserve the existing reason.
            result.state = .needsAttention
        } else if !result.recoveredChunkIDs.isEmpty || result.ignoredPartialJournalTail {
            result.state = .recovered
        } else {
            result.state = .valid
        }

        return result
    }

    /// Best-effort package inventory. A UUID-named symlink/regular file is still
    /// a recovery candidate and therefore appears in `failedRecordingIDs` rather
    /// than silently disappearing from the scan.
    public func recoverAll() async throws -> SuperDictateMemoryRecoveryBatchResult {
        let ids = try await store.recoveryCandidateRecordingIDs()
        var batch = SuperDictateMemoryRecoveryBatchResult()
        batch.results.reserveCapacity(ids.count)

        for id in ids {
            do {
                batch.results.append(try await recover(recordingID: id))
            } catch {
                batch.failedRecordingIDs.append(id)
            }
        }

        batch.results.sort { $0.recordingID.uuidString < $1.recordingID.uuidString }
        batch.failedRecordingIDs.sort { $0.uuidString < $1.uuidString }
        return batch
    }

    private func journalEvent(
        _ event: SuperDictateMemoryRecoveryEvent,
        matches chunk: SuperDictateMemoryAudioChunk
    ) -> Bool {
        event.recordingID == chunkIDRecordingScope(event: event)
            && event.chunkID == chunk.id
            && event.source == chunk.source
            && event.sequence == chunk.sequence
            && event.relativePath == chunk.relativePath
            && event.sessionStartMilliseconds == chunk.sessionStartMilliseconds
            && event.sessionEndMilliseconds == chunk.sessionEndMilliseconds
            && event.container == chunk.container
            && event.codec == chunk.codec
            && event.sampleRate == chunk.sampleRate
            && event.channelCount == chunk.channelCount
            && event.byteLength == chunk.byteLength
    }

    /// Keeps the comparison expression explicit without smuggling a package path
    /// or global into the evidence model. Recording scope is already validated by
    /// the journal loader; return it unchanged for the local equality check.
    private func chunkIDRecordingScope(
        event: SuperDictateMemoryRecoveryEvent
    ) -> UUID {
        event.recordingID
    }

    private func committedEvent(
        from prepared: SuperDictateMemoryRecoveryEvent,
        sha256: String
    ) throws -> SuperDictateMemoryRecoveryEvent {
        try SuperDictateMemoryRecoveryEvent(
            kind: .chunkCommitted,
            recordingID: prepared.recordingID,
            chunkID: prepared.chunkID,
            source: prepared.source,
            sequence: prepared.sequence,
            relativePath: prepared.relativePath,
            sessionStartMilliseconds: prepared.sessionStartMilliseconds,
            sessionEndMilliseconds: prepared.sessionEndMilliseconds,
            container: prepared.container,
            codec: prepared.codec,
            sampleRate: prepared.sampleRate,
            channelCount: prepared.channelCount,
            byteLength: prepared.byteLength,
            sha256: sha256
        )
    }

    private func recoveryIssueMessage(
        _ result: SuperDictateMemoryRecoveryResult
    ) -> String {
        let facts = [
            result.missingChunkIDs.isEmpty ? nil : "missing=\(result.missingChunkIDs.count)",
            result.checksumMismatchChunkIDs.isEmpty ? nil : "checksum=\(result.checksumMismatchChunkIDs.count)",
            result.journalConflictChunkIDs.isEmpty ? nil : "journal=\(result.journalConflictChunkIDs.count)",
            result.quarantinedFileNames.isEmpty ? nil : "quarantined=\(result.quarantinedFileNames.count)",
            result.ignoredPartialJournalTail ? "journal_tail=1" : nil,
        ].compactMap { $0 }

        return facts.isEmpty
            ? "Memory Capture source requires integrity review."
            : "Memory Capture source requires integrity review (\(facts.joined(separator: ", ")))."
    }

    private func appendUnique(_ id: UUID, to values: inout [UUID]) {
        if !values.contains(id) {
            values.append(id)
        }
    }

    private func pathEntryExists(_ url: URL) throws -> Bool {
        var st = stat()
        if Darwin.lstat(url.path, &st) == 0 {
            return true
        }
        if errno == ENOENT {
            return false
        }
        throw SuperDictateMemoryRecoveryError.posix(errno)
    }

    private func validateDirectoryNoFollow(
        _ directory: URL,
        normalizePermissions: Bool = false
    ) throws {
        let fd = Darwin.open(
            directory.path,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard fd >= 0 else {
            if errno == ELOOP {
                throw SuperDictateMemoryRecoveryError.unsafeFileType(
                    directory.lastPathComponent
                )
            }
            throw SuperDictateMemoryRecoveryError.posix(errno)
        }
        defer { _ = Darwin.close(fd) }

        var st = stat()
        guard Darwin.fstat(fd, &st) == 0 else {
            throw SuperDictateMemoryRecoveryError.posix(errno)
        }
        guard (st.st_mode & S_IFMT) == S_IFDIR else {
            throw SuperDictateMemoryRecoveryError.unsafeFileType(
                directory.lastPathComponent
            )
        }
        if normalizePermissions {
            guard Darwin.fchmod(fd, mode_t(0o700)) == 0 else {
                throw SuperDictateMemoryRecoveryError.posix(errno)
            }
        }
    }

    private func sourceFiles(_ directory: URL) throws -> [URL] {
        guard try pathEntryExists(directory) else {
            return []
        }
        try validateDirectoryNoFollow(directory)
        return try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Move the directory entry itself through already-open no-follow parent
    /// descriptors. `renameat` prevents a last-moment quarantine symlink swap
    /// from redirecting preserved source bytes outside the package.
    private func quarantine(
        _ sourceURL: URL,
        into quarantineDirectory: URL
    ) throws -> String {
        let sourceDirectory = sourceURL.deletingLastPathComponent()
        let sourceFD = Darwin.open(
            sourceDirectory.path,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard sourceFD >= 0 else {
            if errno == ELOOP {
                throw SuperDictateMemoryRecoveryError.unsafeFileType(
                    sourceDirectory.lastPathComponent
                )
            }
            throw SuperDictateMemoryRecoveryError.posix(errno)
        }
        defer { _ = Darwin.close(sourceFD) }

        let quarantineFD = Darwin.open(
            quarantineDirectory.path,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard quarantineFD >= 0 else {
            if errno == ELOOP {
                throw SuperDictateMemoryRecoveryError.unsafeFileType(
                    quarantineDirectory.lastPathComponent
                )
            }
            throw SuperDictateMemoryRecoveryError.posix(errno)
        }
        defer { _ = Darwin.close(quarantineFD) }

        guard Darwin.fchmod(quarantineFD, mode_t(0o700)) == 0 else {
            throw SuperDictateMemoryRecoveryError.posix(errno)
        }

        let destinationName = "\(sourceURL.lastPathComponent).quarantine.\(UUID().uuidString.lowercased())"
        let moved = sourceURL.lastPathComponent.withCString { sourceName in
            destinationName.withCString { destinationName in
                Darwin.renameat(sourceFD, sourceName, quarantineFD, destinationName)
            }
        }
        guard moved == 0 else {
            throw SuperDictateMemoryRecoveryError.posix(errno)
        }

        guard Darwin.fsync(sourceFD) == 0,
              Darwin.fsync(quarantineFD) == 0 else {
            throw SuperDictateMemoryRecoveryError.posix(errno)
        }
        return destinationName
    }

    private func inspectCAF(
        _ url: URL
    ) throws -> (byteLength: Int64, sha256: String) {
        let fd = Darwin.open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else {
            if errno == ELOOP {
                throw SuperDictateMemoryRecoveryError.unsafeFileType(
                    url.lastPathComponent
                )
            }
            throw SuperDictateMemoryRecoveryError.posix(errno)
        }
        defer { _ = Darwin.close(fd) }

        var st = stat()
        guard Darwin.fstat(fd, &st) == 0 else {
            throw SuperDictateMemoryRecoveryError.posix(errno)
        }
        guard (st.st_mode & S_IFMT) == S_IFREG,
              st.st_nlink == 1 else {
            throw SuperDictateMemoryRecoveryError.unsafeFileType(
                url.lastPathComponent
            )
        }

        let byteLength = Int64(st.st_size)
        guard byteLength <= policy.maximumChunkBytes else {
            throw SuperDictateMemoryRecoveryError.fileTooLarge(
                path: url.lastPathComponent,
                actual: byteLength,
                maximum: policy.maximumChunkBytes
            )
        }
        guard byteLength >= 4 else {
            throw SuperDictateMemoryRecoveryError.invalidContainer(
                url.lastPathComponent
            )
        }

        var hasher = SHA256()
        var firstFour: [UInt8] = []
        var buffer = [UInt8](repeating: 0, count: 256 * 1_024)
        while true {
            let count = buffer.withUnsafeMutableBytes {
                Darwin.read(fd, $0.baseAddress, $0.count)
            }
            if count < 0 {
                if errno == EINTR {
                    continue
                }
                throw SuperDictateMemoryRecoveryError.posix(errno)
            }
            guard count > 0 else {
                break
            }
            if firstFour.count < 4 {
                firstFour.append(
                    contentsOf: buffer.prefix(min(count, 4 - firstFour.count))
                )
            }
            hasher.update(data: Data(buffer.prefix(count)))
        }

        guard firstFour == Array("caff".utf8) else {
            throw SuperDictateMemoryRecoveryError.invalidContainer(
                url.lastPathComponent
            )
        }

        return (
            byteLength: byteLength,
            sha256: hasher.finalize().map { String(format: "%02x", $0) }.joined()
        )
    }
}
