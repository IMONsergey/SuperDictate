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
    public var quarantinedFileNames: [String]
    public var ignoredPartialJournalTail: Bool

    public init(
        recordingID: UUID,
        state: SuperDictateMemoryRecoveryState = .valid,
        recoveredChunkIDs: [UUID] = [],
        missingChunkIDs: [UUID] = [],
        checksumMismatchChunkIDs: [UUID] = [],
        quarantinedFileNames: [String] = [],
        ignoredPartialJournalTail: Bool = false
    ) {
        self.recordingID = recordingID
        self.state = state
        self.recoveredChunkIDs = recoveredChunkIDs
        self.missingChunkIDs = missingChunkIDs
        self.checksumMismatchChunkIDs = checksumMismatchChunkIDs
        self.quarantinedFileNames = quarantinedFileNames
        self.ignoredPartialJournalTail = ignoredPartialJournalTail
    }
}

public enum SuperDictateMemoryRecoveryError: Error, Equatable, Sendable {
    case unsafeFileType(String)
    case invalidContainer(String)
    case byteLengthMismatch(path: String, expected: Int64, actual: Int64)
    case fileOperationFailed(String)
    case posix(Int32)
}

/// Conservative recovery for authoritative Memory Capture source packages.
///
/// Rules:
/// - manifest-referenced chunks must still match byte length + CAF magic + SHA;
/// - `.partial` files are never interpreted as finalized audio;
/// - a finalized orphan may be reattached only when an fsynced prepared journal
///   event proves its timing, format and source metadata;
/// - undocumented or conflicting files are quarantined, never silently deleted;
/// - any physical integrity failure moves the package to `needsAttention`, even
///   if it had previously reached `.ready`.
public actor SuperDictateMemoryPackageRecovery {
    private let store: JSONSuperDictateMemoryPackageStore
    private let fileManager: FileManager

    public init(
        store: JSONSuperDictateMemoryPackageStore,
        fileManager: FileManager = .default
    ) {
        self.store = store
        self.fileManager = fileManager
    }

    public func recover(recordingID: UUID) async throws -> SuperDictateMemoryRecoveryResult {
        guard var manifest = try await store.loadManifest(recordingID: recordingID) else {
            throw SuperDictateMemoryPackageStoreError.packageMissing(recordingID)
        }
        let journal = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        var result = SuperDictateMemoryRecoveryResult(
            recordingID: recordingID,
            ignoredPartialJournalTail: journal.ignoredPartialTailLine
        )
        // A torn final JSONL append is expected crash fallout. If every source
        // file and manifest descriptor is healthy, report `recovered`, not an
        // alarming integrity failure.
        var needsAttention = false

        let packageURL = await store.packageURL(recordingID: recordingID)
        let quarantineURL = await store.quarantineDirectory(recordingID: recordingID)

        // First validate every chunk the manifest already claims as durable.
        var referencedRelativePaths: Set<String> = []
        var observedRecoveryRelativePaths: Set<String> = []
        for chunk in manifest.chunks {
            referencedRelativePaths.insert(chunk.relativePath)
            let url = packageURL.appendingPathComponent(chunk.relativePath, isDirectory: false)
            guard try pathEntryExists(url) else {
                appendUnique(chunk.id, to: &result.missingChunkIDs)
                needsAttention = true
                continue
            }
            observedRecoveryRelativePaths.insert(chunk.relativePath)

            do {
                let inspection = try inspectCAF(url)
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
                        try quarantine(url, into: quarantineURL)
                    )
                    needsAttention = true
                    continue
                }
            } catch {
                // `lstat` above means even a broken symlink reaches this branch;
                // move the suspicious directory entry itself without following it.
                result.quarantinedFileNames.append(
                    try quarantine(url, into: quarantineURL)
                )
                needsAttention = true
            }
        }

        // Then classify files that exist on disk but are not in the manifest.
        // Partials are always quarantined; finalized orphans require journal proof.
        let latestJournalByPath = journal.events.reduce(into: [String: SuperDictateMemoryRecoveryEvent]()) {
            result, event in
            result[event.relativePath] = event
        }

        for source in SuperDictateMemoryAudioSource.allCases {
            let sourceDirectory = await store.audioDirectory(recordingID: recordingID, source: source)
            for url in try sourceFiles(sourceDirectory) {
                let relativePath = "audio/\(source.rawValue)/\(url.lastPathComponent)"
                if url.pathExtension == "partial" {
                    let finalRelativePath = String(relativePath.dropLast(".partial".count))
                    observedRecoveryRelativePaths.insert(finalRelativePath)
                } else {
                    observedRecoveryRelativePaths.insert(relativePath)
                }

                if referencedRelativePaths.contains(relativePath) {
                    continue
                }

                if url.pathExtension == "partial" {
                    result.quarantinedFileNames.append(
                        try quarantine(url, into: quarantineURL)
                    )
                    needsAttention = true
                    continue
                }

                guard url.pathExtension == SuperDictateMemoryAudioContainer.caf.rawValue else {
                    result.quarantinedFileNames.append(
                        try quarantine(url, into: quarantineURL)
                    )
                    needsAttention = true
                    continue
                }

                guard let event = latestJournalByPath[relativePath],
                      event.recordingID == recordingID,
                      event.source == source else {
                    result.quarantinedFileNames.append(
                        try quarantine(url, into: quarantineURL)
                    )
                    needsAttention = true
                    continue
                }

                do {
                    let inspection = try inspectCAF(url)
                    guard inspection.byteLength == event.byteLength else {
                        throw SuperDictateMemoryRecoveryError.byteLengthMismatch(
                            path: relativePath,
                            expected: event.byteLength,
                            actual: inspection.byteLength
                        )
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
                    manifest = try await store.appendFinalizedChunk(
                        recordingID: recordingID,
                        chunk: descriptor
                    )
                    referencedRelativePaths.insert(relativePath)
                    appendUnique(event.chunkID, to: &result.recoveredChunkIDs)

                    // Close a stale prepared event after successful manifest repair.
                    if event.kind == .chunkPrepared,
                       let committed = try? SuperDictateMemoryRecoveryEvent(
                           kind: .chunkCommitted,
                           recordingID: event.recordingID,
                           chunkID: event.chunkID,
                           source: event.source,
                           sequence: event.sequence,
                           relativePath: event.relativePath,
                           sessionStartMilliseconds: event.sessionStartMilliseconds,
                           sessionEndMilliseconds: event.sessionEndMilliseconds,
                           container: event.container,
                           codec: event.codec,
                           sampleRate: event.sampleRate,
                           channelCount: event.channelCount,
                           byteLength: event.byteLength
                       ) {
                        try? await store.appendRecoveryEvent(committed)
                    }
                } catch {
                    result.quarantinedFileNames.append(
                        try quarantine(url, into: quarantineURL)
                    )
                    needsAttention = true
                }
            }
        }

        // A durable journal event is itself evidence that source bytes existed.
        // If neither the manifest nor a partial/final file accounts for its path,
        // report the source as missing instead of silently forgetting the event.
        for event in latestJournalByPath.values {
            guard !observedRecoveryRelativePaths.contains(event.relativePath) else { continue }
            appendUnique(event.chunkID, to: &result.missingChunkIDs)
            needsAttention = true
        }

        result.missingChunkIDs.sort { $0.uuidString < $1.uuidString }
        result.checksumMismatchChunkIDs.sort { $0.uuidString < $1.uuidString }
        result.recoveredChunkIDs.sort { $0.uuidString < $1.uuidString }
        result.quarantinedFileNames.sort()

        if needsAttention {
            _ = try await store.markIntegrityNeedsAttention(
                recordingID: recordingID,
                message: recoveryIssueMessage(result)
            )
            result.state = .needsAttention
        } else if !result.recoveredChunkIDs.isEmpty || result.ignoredPartialJournalTail {
            result.state = .recovered
        } else {
            result.state = .valid
        }

        return result
    }

    public func recoverAll() async throws -> [SuperDictateMemoryRecoveryResult] {
        let ids = try await store.existingRecordingIDs()
        var results: [SuperDictateMemoryRecoveryResult] = []
        results.reserveCapacity(ids.count)
        for id in ids {
            results.append(try await recover(recordingID: id))
        }
        return results.sorted { $0.recordingID.uuidString < $1.recordingID.uuidString }
    }

    private func recoveryIssueMessage(_ result: SuperDictateMemoryRecoveryResult) -> String {
        let facts = [
            result.missingChunkIDs.isEmpty ? nil : "missing=\(result.missingChunkIDs.count)",
            result.checksumMismatchChunkIDs.isEmpty ? nil : "checksum=\(result.checksumMismatchChunkIDs.count)",
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

    private func sourceFiles(_ directory: URL) throws -> [URL] {
        guard try pathEntryExists(directory) else { return [] }
        var st = stat()
        guard Darwin.lstat(directory.path, &st) == 0 else {
            throw SuperDictateMemoryRecoveryError.posix(errno)
        }
        guard (st.st_mode & S_IFMT) == S_IFDIR else {
            throw SuperDictateMemoryRecoveryError.unsafeFileType(directory.lastPathComponent)
        }
        return try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func quarantine(_ url: URL, into directory: URL) throws -> String {
        let destination = directory.appendingPathComponent(
            "\(url.lastPathComponent).quarantine.\(UUID().uuidString.lowercased())",
            isDirectory: false
        )
        do {
            try fileManager.moveItem(at: url, to: destination)
        } catch {
            throw SuperDictateMemoryRecoveryError.fileOperationFailed(
                error.localizedDescription
            )
        }
        try synchronizeDirectory(directory)
        return destination.lastPathComponent
    }

    private func synchronizeDirectory(_ directory: URL) throws {
        let fd = Darwin.open(directory.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else {
            if errno == ELOOP {
                throw SuperDictateMemoryRecoveryError.unsafeFileType(directory.lastPathComponent)
            }
            throw SuperDictateMemoryRecoveryError.posix(errno)
        }
        defer { _ = Darwin.close(fd) }
        guard Darwin.fsync(fd) == 0 else {
            throw SuperDictateMemoryRecoveryError.posix(errno)
        }
    }

    private func inspectCAF(_ url: URL) throws -> (byteLength: Int64, sha256: String) {
        let fd = Darwin.open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else {
            if errno == ELOOP {
                throw SuperDictateMemoryRecoveryError.unsafeFileType(url.lastPathComponent)
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
            throw SuperDictateMemoryRecoveryError.unsafeFileType(url.lastPathComponent)
        }
        guard st.st_size >= 4 else {
            throw SuperDictateMemoryRecoveryError.invalidContainer(url.lastPathComponent)
        }

        var hasher = SHA256()
        var firstFour: [UInt8] = []
        var buffer = [UInt8](repeating: 0, count: 256 * 1_024)
        while true {
            let count = buffer.withUnsafeMutableBytes { raw in
                Darwin.read(fd, raw.baseAddress, raw.count)
            }
            if count < 0 {
                if errno == EINTR { continue }
                throw SuperDictateMemoryRecoveryError.posix(errno)
            }
            guard count > 0 else { break }
            if firstFour.count < 4 {
                firstFour.append(contentsOf: buffer.prefix(min(count, 4 - firstFour.count)))
            }
            hasher.update(data: Data(buffer.prefix(count)))
        }
        guard firstFour == Array("caff".utf8) else {
            throw SuperDictateMemoryRecoveryError.invalidContainer(url.lastPathComponent)
        }

        return (
            byteLength: Int64(st.st_size),
            sha256: hasher.finalize().map { String(format: "%02x", $0) }.joined()
        )
    }
}
