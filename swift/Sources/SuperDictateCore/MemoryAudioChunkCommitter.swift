import CryptoKit
import Darwin
import Foundation

public struct SuperDictateMemoryChunkPolicy: Equatable, Sendable {
    public var maximumChunkBytes: Int64
    public var partialSuffix: String

    public init(
        maximumChunkBytes: Int64 = 32 * 1_024 * 1_024,
        partialSuffix: String = "partial"
    ) {
        self.maximumChunkBytes = max(1, maximumChunkBytes)
        let normalized = partialSuffix.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = !normalized.isEmpty && normalized.allSatisfy {
            $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_"
        }
        self.partialSuffix = safe ? normalized : "partial"
    }
}

public enum SuperDictateMemoryChunkCommitError: Error, Equatable, Sendable {
    case invalidSequence(Int)
    case unexpectedTemporaryPath
    case temporaryChunkMissing
    case unsafeFileType
    case invalidContainer
    case emptyChunk
    case fileTooLarge(Int64, Int64)
    case destinationAlreadyExists(String)
    case recoveryRequired(recordingID: UUID, chunkID: UUID)
    case posix(Int32)
}

public actor SuperDictateMemoryAudioChunkCommitter {
    private let store: JSONSuperDictateMemoryPackageStore
    private let policy: SuperDictateMemoryChunkPolicy

    public init(
        store: JSONSuperDictateMemoryPackageStore,
        policy: SuperDictateMemoryChunkPolicy = SuperDictateMemoryChunkPolicy()
    ) {
        self.store = store
        self.policy = policy
    }

    public func temporaryChunkURL(
        recordingID: UUID,
        source: SuperDictateMemoryAudioSource,
        sequence: Int,
        chunkID: UUID
    ) async throws -> URL {
        guard sequence >= 0 else {
            throw SuperDictateMemoryChunkCommitError.invalidSequence(sequence)
        }
        let directory = await store.audioDirectory(recordingID: recordingID, source: source)
        return directory.appendingPathComponent(
            Self.temporaryFileName(
                sequence: sequence,
                chunkID: chunkID,
                partialSuffix: policy.partialSuffix
            ),
            isDirectory: false
        )
    }

    @discardableResult
    public func commitChunk(
        recordingID: UUID,
        source: SuperDictateMemoryAudioSource,
        sequence: Int,
        chunkID: UUID,
        temporaryURL: URL,
        sessionStartMilliseconds: Int64,
        sessionEndMilliseconds: Int64,
        sampleRate: Int,
        channelCount: Int
    ) async throws -> SuperDictateMemoryAudioChunk {
        guard sequence >= 0 else {
            throw SuperDictateMemoryChunkCommitError.invalidSequence(sequence)
        }
        guard sessionStartMilliseconds >= 0,
              sessionEndMilliseconds >= sessionStartMilliseconds else {
            throw SuperDictateMemoryManifestError.invalidTiming
        }
        guard sampleRate > 0,
              channelCount == 1 || channelCount == 2 else {
            throw SuperDictateMemoryManifestError.invalidAudioFormat
        }

        let expectedTemporaryURL = try await temporaryChunkURL(
            recordingID: recordingID,
            source: source,
            sequence: sequence,
            chunkID: chunkID
        )
        guard temporaryURL.standardizedFileURL == expectedTemporaryURL.standardizedFileURL else {
            throw SuperDictateMemoryChunkCommitError.unexpectedTemporaryPath
        }
        guard let manifest = try await store.loadManifest(recordingID: recordingID) else {
            throw SuperDictateMemoryPackageStoreError.packageMissing(recordingID)
        }
        guard manifest.state == .recording || manifest.state == .finalizing else {
            throw SuperDictateMemoryManifestError.chunkAppendNotAllowed(manifest.state)
        }

        let byteLength = try flushAndValidateTemporaryFile(temporaryURL)
        let finalURL = Self.finalizedURL(from: temporaryURL, partialSuffix: policy.partialSuffix)
        try assertDestinationAbsent(finalURL)
        let relativePath = SuperDictateMemoryAudioChunk.canonicalRelativePath(
            source: source,
            sequence: sequence,
            chunkID: chunkID
        )

        let prepared = try recoveryEvent(
            kind: .chunkPrepared,
            recordingID: recordingID,
            source: source,
            sequence: sequence,
            chunkID: chunkID,
            relativePath: relativePath,
            sessionStartMilliseconds: sessionStartMilliseconds,
            sessionEndMilliseconds: sessionEndMilliseconds,
            sampleRate: sampleRate,
            channelCount: channelCount,
            byteLength: byteLength,
            sha256: nil
        )
        try await store.appendRecoveryEvent(prepared)

        guard Darwin.rename(temporaryURL.path, finalURL.path) == 0 else {
            throw SuperDictateMemoryChunkCommitError.posix(errno)
        }
        try synchronizeDirectory(finalURL.deletingLastPathComponent())

        do {
            let checksum = try sha256Hex(finalURL)
            let descriptor = try SuperDictateMemoryAudioChunk(
                id: chunkID,
                source: source,
                sequence: sequence,
                relativePath: relativePath,
                sessionStartMilliseconds: sessionStartMilliseconds,
                sessionEndMilliseconds: sessionEndMilliseconds,
                container: .caf,
                codec: .linearPCM,
                sampleRate: sampleRate,
                channelCount: channelCount,
                byteLength: byteLength,
                sha256: checksum
            )
            _ = try await store.appendFinalizedChunk(
                recordingID: recordingID,
                chunk: descriptor
            )

            // Manifest is already authoritative at this point. The committed
            // marker is best-effort, but when present it cryptographically binds
            // any later manifest reconstruction to the original finalized bytes.
            if let committed = try? recoveryEvent(
                kind: .chunkCommitted,
                recordingID: recordingID,
                source: source,
                sequence: sequence,
                chunkID: chunkID,
                relativePath: relativePath,
                sessionStartMilliseconds: sessionStartMilliseconds,
                sessionEndMilliseconds: sessionEndMilliseconds,
                sampleRate: sampleRate,
                channelCount: channelCount,
                byteLength: byteLength,
                sha256: checksum
            ) {
                try? await store.appendRecoveryEvent(committed)
            }
            return descriptor
        } catch {
            throw SuperDictateMemoryChunkCommitError.recoveryRequired(
                recordingID: recordingID,
                chunkID: chunkID
            )
        }
    }

    private func recoveryEvent(
        kind: SuperDictateMemoryRecoveryEventKind,
        recordingID: UUID,
        source: SuperDictateMemoryAudioSource,
        sequence: Int,
        chunkID: UUID,
        relativePath: String,
        sessionStartMilliseconds: Int64,
        sessionEndMilliseconds: Int64,
        sampleRate: Int,
        channelCount: Int,
        byteLength: Int64,
        sha256: String?
    ) throws -> SuperDictateMemoryRecoveryEvent {
        try SuperDictateMemoryRecoveryEvent(
            kind: kind,
            recordingID: recordingID,
            chunkID: chunkID,
            source: source,
            sequence: sequence,
            relativePath: relativePath,
            sessionStartMilliseconds: sessionStartMilliseconds,
            sessionEndMilliseconds: sessionEndMilliseconds,
            container: .caf,
            codec: .linearPCM,
            sampleRate: sampleRate,
            channelCount: channelCount,
            byteLength: byteLength,
            sha256: sha256
        )
    }

    private func flushAndValidateTemporaryFile(_ url: URL) throws -> Int64 {
        let fd = Darwin.open(url.path, O_RDWR | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else {
            if errno == ENOENT { throw SuperDictateMemoryChunkCommitError.temporaryChunkMissing }
            if errno == ELOOP { throw SuperDictateMemoryChunkCommitError.unsafeFileType }
            throw SuperDictateMemoryChunkCommitError.posix(errno)
        }
        defer { _ = Darwin.close(fd) }

        var st = stat()
        guard Darwin.fstat(fd, &st) == 0 else {
            throw SuperDictateMemoryChunkCommitError.posix(errno)
        }
        guard (st.st_mode & S_IFMT) == S_IFREG, st.st_nlink == 1 else {
            throw SuperDictateMemoryChunkCommitError.unsafeFileType
        }
        guard st.st_size > 0 else { throw SuperDictateMemoryChunkCommitError.emptyChunk }
        guard st.st_size <= off_t(policy.maximumChunkBytes) else {
            throw SuperDictateMemoryChunkCommitError.fileTooLarge(Int64(st.st_size), policy.maximumChunkBytes)
        }

        var magic = [UInt8](repeating: 0, count: 4)
        let magicCount: Int = magic.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return -1 }
            return Darwin.pread(fd, baseAddress, bytes.count, 0)
        }
        guard magicCount == 4, magic == Array("caff".utf8) else {
            throw SuperDictateMemoryChunkCommitError.invalidContainer
        }
        guard Darwin.fchmod(fd, mode_t(0o600)) == 0 else {
            throw SuperDictateMemoryChunkCommitError.posix(errno)
        }
        guard Darwin.fsync(fd) == 0 else {
            throw SuperDictateMemoryChunkCommitError.posix(errno)
        }
        return Int64(st.st_size)
    }

    private func assertDestinationAbsent(_ url: URL) throws {
        var st = stat()
        if Darwin.lstat(url.path, &st) == 0 {
            throw SuperDictateMemoryChunkCommitError.destinationAlreadyExists(url.lastPathComponent)
        }
        guard errno == ENOENT else { throw SuperDictateMemoryChunkCommitError.posix(errno) }
    }

    private func synchronizeDirectory(_ url: URL) throws {
        let fd = Darwin.open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else {
            if errno == ELOOP { throw SuperDictateMemoryChunkCommitError.unsafeFileType }
            throw SuperDictateMemoryChunkCommitError.posix(errno)
        }
        defer { _ = Darwin.close(fd) }
        guard Darwin.fsync(fd) == 0 else { throw SuperDictateMemoryChunkCommitError.posix(errno) }
    }

    private func sha256Hex(_ url: URL) throws -> String {
        let fd = Darwin.open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else {
            if errno == ELOOP { throw SuperDictateMemoryChunkCommitError.unsafeFileType }
            throw SuperDictateMemoryChunkCommitError.posix(errno)
        }
        defer { _ = Darwin.close(fd) }
        var st = stat()
        guard Darwin.fstat(fd, &st) == 0 else { throw SuperDictateMemoryChunkCommitError.posix(errno) }
        guard (st.st_mode & S_IFMT) == S_IFREG, st.st_nlink == 1 else {
            throw SuperDictateMemoryChunkCommitError.unsafeFileType
        }
        var hasher = SHA256()
        var buffer = [UInt8](repeating: 0, count: 256 * 1_024)
        while true {
            let count = buffer.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress, $0.count) }
            if count < 0 {
                if errno == EINTR { continue }
                throw SuperDictateMemoryChunkCommitError.posix(errno)
            }
            guard count > 0 else { break }
            hasher.update(data: Data(buffer.prefix(count)))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func temporaryFileName(sequence: Int, chunkID: UUID, partialSuffix: String) -> String {
        let sequenceText = String(format: "%06d", sequence)
        return "\(sequenceText)__\(chunkID.uuidString.lowercased()).caf.\(partialSuffix)"
    }

    private static func finalizedURL(from temporaryURL: URL, partialSuffix: String) -> URL {
        let suffix = ".\(partialSuffix)"
        let path = temporaryURL.path
        return path.hasSuffix(suffix)
            ? URL(fileURLWithPath: String(path.dropLast(suffix.count)))
            : temporaryURL
    }
}
