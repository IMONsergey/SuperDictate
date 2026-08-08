import Darwin
import Foundation

public enum SuperDictateMemoryRecoveryEventKind: String, Codable, Sendable {
    case chunkPrepared = "chunk_prepared"
    case chunkCommitted = "chunk_committed"
}

public struct SuperDictateMemoryRecoveryEvent: Codable, Equatable, Sendable, Identifiable {
    public static let schemaVersion = 1

    public let schemaVersion: Int
    public let id: UUID
    public let kind: SuperDictateMemoryRecoveryEventKind
    public let recordingID: UUID
    public let chunkID: UUID
    public let source: SuperDictateMemoryAudioSource
    public let sequence: Int
    public let relativePath: String
    public let sessionStartMilliseconds: Int64
    public let sessionEndMilliseconds: Int64
    public let container: SuperDictateMemoryAudioContainer
    public let codec: SuperDictateMemoryAudioCodec
    public let sampleRate: Int
    public let channelCount: Int
    public let byteLength: Int64
    public let sha256: String?
    public let createdAt: Date

    public init(
        schemaVersion: Int = SuperDictateMemoryRecoveryEvent.schemaVersion,
        id: UUID = UUID(),
        kind: SuperDictateMemoryRecoveryEventKind,
        recordingID: UUID,
        chunkID: UUID,
        source: SuperDictateMemoryAudioSource,
        sequence: Int,
        relativePath: String,
        sessionStartMilliseconds: Int64,
        sessionEndMilliseconds: Int64,
        container: SuperDictateMemoryAudioContainer = .caf,
        codec: SuperDictateMemoryAudioCodec = .linearPCM,
        sampleRate: Int,
        channelCount: Int,
        byteLength: Int64,
        sha256: String? = nil,
        createdAt: Date = Date()
    ) throws {
        guard schemaVersion == Self.schemaVersion else {
            throw SuperDictateMemoryRecoveryJournalError.unsupportedSchema(schemaVersion)
        }
        guard sequence >= 0,
              sessionStartMilliseconds >= 0,
              sessionEndMilliseconds >= sessionStartMilliseconds,
              byteLength > 0,
              sampleRate > 0,
              channelCount == 1 || channelCount == 2 else {
            throw SuperDictateMemoryRecoveryJournalError.invalidMetadata
        }

        let path = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard path == SuperDictateMemoryAudioChunk.canonicalRelativePath(
            source: source,
            sequence: sequence,
            chunkID: chunkID,
            container: container
        ) else {
            throw SuperDictateMemoryRecoveryJournalError.invalidRelativePath(relativePath)
        }

        let normalizedSHA = sha256?.lowercased()
        switch kind {
        case .chunkPrepared:
            guard normalizedSHA == nil else {
                throw SuperDictateMemoryRecoveryJournalError.invalidSHA256(sha256 ?? "")
            }
        case .chunkCommitted:
            guard let normalizedSHA,
                  Self.isSHA256(normalizedSHA) else {
                throw SuperDictateMemoryRecoveryJournalError.invalidSHA256(sha256 ?? "")
            }
        }

        self.schemaVersion = schemaVersion
        self.id = id
        self.kind = kind
        self.recordingID = recordingID
        self.chunkID = chunkID
        self.source = source
        self.sequence = sequence
        self.relativePath = path
        self.sessionStartMilliseconds = sessionStartMilliseconds
        self.sessionEndMilliseconds = sessionEndMilliseconds
        self.container = container
        self.codec = codec
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.byteLength = byteLength
        self.sha256 = normalizedSHA
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, kind, recordingID, chunkID, source, sequence
        case relativePath, sessionStartMilliseconds, sessionEndMilliseconds
        case container, codec, sampleRate, channelCount, byteLength, sha256, createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: c.decode(Int.self, forKey: .schemaVersion),
            id: c.decode(UUID.self, forKey: .id),
            kind: c.decode(SuperDictateMemoryRecoveryEventKind.self, forKey: .kind),
            recordingID: c.decode(UUID.self, forKey: .recordingID),
            chunkID: c.decode(UUID.self, forKey: .chunkID),
            source: c.decode(SuperDictateMemoryAudioSource.self, forKey: .source),
            sequence: c.decode(Int.self, forKey: .sequence),
            relativePath: c.decode(String.self, forKey: .relativePath),
            sessionStartMilliseconds: c.decode(Int64.self, forKey: .sessionStartMilliseconds),
            sessionEndMilliseconds: c.decode(Int64.self, forKey: .sessionEndMilliseconds),
            container: c.decode(SuperDictateMemoryAudioContainer.self, forKey: .container),
            codec: c.decode(SuperDictateMemoryAudioCodec.self, forKey: .codec),
            sampleRate: c.decode(Int.self, forKey: .sampleRate),
            channelCount: c.decode(Int.self, forKey: .channelCount),
            byteLength: c.decode(Int64.self, forKey: .byteLength),
            sha256: c.decodeIfPresent(String.self, forKey: .sha256),
            createdAt: c.decode(Date.self, forKey: .createdAt)
        )
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }
}

public enum SuperDictateMemoryRecoveryJournalError: Error, Equatable, Sendable {
    case unsupportedSchema(Int)
    case invalidMetadata
    case invalidRelativePath(String)
    case invalidSHA256(String)
    case invalidTransition(
        chunkID: UUID,
        previous: SuperDictateMemoryRecoveryEventKind?,
        next: SuperDictateMemoryRecoveryEventKind
    )
    case conflictingChunkMetadata(UUID)
    case unsafeFileType
    case fileTooLarge(Int, Int)
    case corruptLine(Int)
    case posix(Int32)
}

public struct SuperDictateMemoryRecoveryJournalSnapshot: Equatable, Sendable {
    public var events: [SuperDictateMemoryRecoveryEvent]
    public var ignoredPartialTailLine: Bool

    public init(events: [SuperDictateMemoryRecoveryEvent], ignoredPartialTailLine: Bool = false) {
        self.events = events
        self.ignoredPartialTailLine = ignoredPartialTailLine
    }

    public var latestEventByChunkID: [UUID: SuperDictateMemoryRecoveryEvent] {
        events.reduce(into: [:]) { $0[$1.chunkID] = $1 }
    }
}

public extension JSONSuperDictateMemoryPackageStore {
    static var maximumRecoveryJournalBytes: Int { 8 * 1_024 * 1_024 }

    func appendRecoveryEvent(_ event: SuperDictateMemoryRecoveryEvent) throws {
        guard try loadManifest(recordingID: event.recordingID) != nil else {
            throw SuperDictateMemoryPackageStoreError.packageMissing(event.recordingID)
        }
        let snapshot = try recoveryJournalSnapshot(recordingID: event.recordingID)
        try Self.validateRecoveryTransition(existing: snapshot.events, next: event)

        let url = recoveryJournalURL(recordingID: event.recordingID)
        try Self.normalizeRecoveryJournalTail(
            url,
            snapshot: snapshot,
            maximumBytes: Self.maximumRecoveryJournalBytes
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        var line = try encoder.encode(event)
        line.append(UInt8(ascii: "\n"))

        let fd = Darwin.open(
            url.path,
            O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC | O_NOFOLLOW,
            mode_t(0o600)
        )
        guard fd >= 0 else {
            if errno == ELOOP { throw SuperDictateMemoryRecoveryJournalError.unsafeFileType }
            throw SuperDictateMemoryRecoveryJournalError.posix(errno)
        }
        defer { _ = Darwin.close(fd) }

        var st = stat()
        guard Darwin.fstat(fd, &st) == 0 else {
            throw SuperDictateMemoryRecoveryJournalError.posix(errno)
        }
        guard (st.st_mode & S_IFMT) == S_IFREG,
              st.st_nlink == 1 else {
            throw SuperDictateMemoryRecoveryJournalError.unsafeFileType
        }
        guard st.st_size + off_t(line.count) <= off_t(Self.maximumRecoveryJournalBytes) else {
            throw SuperDictateMemoryRecoveryJournalError.fileTooLarge(
                Int(st.st_size) + line.count,
                Self.maximumRecoveryJournalBytes
            )
        }
        guard Darwin.fchmod(fd, mode_t(0o600)) == 0 else {
            throw SuperDictateMemoryRecoveryJournalError.posix(errno)
        }
        try Self.writeRecoveryBytes(line, fd: fd)
        guard Darwin.fsync(fd) == 0 else {
            throw SuperDictateMemoryRecoveryJournalError.posix(errno)
        }
    }

    func recoveryJournalSnapshot(
        recordingID: UUID
    ) throws -> SuperDictateMemoryRecoveryJournalSnapshot {
        guard try loadManifest(recordingID: recordingID) != nil else {
            throw SuperDictateMemoryPackageStoreError.packageMissing(recordingID)
        }
        let url = recoveryJournalURL(recordingID: recordingID)

        var st = stat()
        if Darwin.lstat(url.path, &st) != 0 {
            if errno == ENOENT {
                return SuperDictateMemoryRecoveryJournalSnapshot(events: [])
            }
            throw SuperDictateMemoryRecoveryJournalError.posix(errno)
        }
        guard (st.st_mode & S_IFMT) == S_IFREG,
              st.st_nlink == 1 else {
            throw SuperDictateMemoryRecoveryJournalError.unsafeFileType
        }

        let data = try Self.readRecoveryBytes(
            url,
            maximumBytes: Self.maximumRecoveryJournalBytes
        )
        guard !data.isEmpty else {
            return SuperDictateMemoryRecoveryJournalSnapshot(events: [])
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let lines = data.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: false)
        var events: [SuperDictateMemoryRecoveryEvent] = []
        var ignoredTail = false

        for (index, line) in lines.enumerated() {
            if line.isEmpty { continue }
            do {
                let event = try decoder.decode(
                    SuperDictateMemoryRecoveryEvent.self,
                    from: Data(line)
                )
                guard event.recordingID == recordingID else {
                    throw SuperDictateMemoryRecoveryJournalError.invalidMetadata
                }
                try Self.validateRecoveryTransition(existing: events, next: event)
                events.append(event)
            } catch {
                let finalPhysicalLine = index == lines.count - 1
                let terminated = data.last == UInt8(ascii: "\n")
                if finalPhysicalLine && !terminated {
                    ignoredTail = true
                    break
                }
                if let typed = error as? SuperDictateMemoryRecoveryJournalError {
                    throw typed
                }
                throw SuperDictateMemoryRecoveryJournalError.corruptLine(index + 1)
            }
        }
        return SuperDictateMemoryRecoveryJournalSnapshot(
            events: events,
            ignoredPartialTailLine: ignoredTail
        )
    }

    func recoveryJournalURL(recordingID: UUID) -> URL {
        packageURL(recordingID: recordingID)
            .appendingPathComponent("recovery.jsonl", isDirectory: false)
    }

    private static func validateRecoveryTransition(
        existing: [SuperDictateMemoryRecoveryEvent],
        next: SuperDictateMemoryRecoveryEvent
    ) throws {
        let previous = existing.last(where: { $0.chunkID == next.chunkID })
        if let previous {
            guard previous.recordingID == next.recordingID,
                  previous.source == next.source,
                  previous.sequence == next.sequence,
                  previous.relativePath == next.relativePath,
                  previous.sessionStartMilliseconds == next.sessionStartMilliseconds,
                  previous.sessionEndMilliseconds == next.sessionEndMilliseconds,
                  previous.container == next.container,
                  previous.codec == next.codec,
                  previous.sampleRate == next.sampleRate,
                  previous.channelCount == next.channelCount,
                  previous.byteLength == next.byteLength else {
                throw SuperDictateMemoryRecoveryJournalError.conflictingChunkMetadata(next.chunkID)
            }
        }
        switch (previous?.kind, next.kind) {
        case (nil, .chunkPrepared),
             (.some(.chunkPrepared), .chunkCommitted):
            return
        default:
            throw SuperDictateMemoryRecoveryJournalError.invalidTransition(
                chunkID: next.chunkID,
                previous: previous?.kind,
                next: next.kind
            )
        }
    }

    /// Make a previously crashed JSONL file safe to append again.
    /// - invalid physical tail: truncate it to the last durable newline;
    /// - valid final JSON without newline: preserve it and add the separator;
    /// - already terminated file: no-op.
    private static func normalizeRecoveryJournalTail(
        _ url: URL,
        snapshot: SuperDictateMemoryRecoveryJournalSnapshot,
        maximumBytes: Int
    ) throws {
        var pathStat = stat()
        if Darwin.lstat(url.path, &pathStat) != 0 {
            if errno == ENOENT { return }
            throw SuperDictateMemoryRecoveryJournalError.posix(errno)
        }
        guard (pathStat.st_mode & S_IFMT) == S_IFREG,
              pathStat.st_nlink == 1 else {
            throw SuperDictateMemoryRecoveryJournalError.unsafeFileType
        }

        let data = try readRecoveryBytes(url, maximumBytes: maximumBytes)
        guard !data.isEmpty,
              data.last != UInt8(ascii: "\n") else {
            return
        }

        let fd = Darwin.open(url.path, O_RDWR | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else {
            if errno == ELOOP { throw SuperDictateMemoryRecoveryJournalError.unsafeFileType }
            throw SuperDictateMemoryRecoveryJournalError.posix(errno)
        }
        defer { _ = Darwin.close(fd) }

        var st = stat()
        guard Darwin.fstat(fd, &st) == 0 else {
            throw SuperDictateMemoryRecoveryJournalError.posix(errno)
        }
        guard (st.st_mode & S_IFMT) == S_IFREG,
              st.st_nlink == 1 else {
            throw SuperDictateMemoryRecoveryJournalError.unsafeFileType
        }

        if snapshot.ignoredPartialTailLine {
            if let newline = data.lastIndex(of: UInt8(ascii: "\n")) {
                guard Darwin.ftruncate(fd, off_t(newline + 1)) == 0 else {
                    throw SuperDictateMemoryRecoveryJournalError.posix(errno)
                }
            } else {
                guard Darwin.ftruncate(fd, 0) == 0 else {
                    throw SuperDictateMemoryRecoveryJournalError.posix(errno)
                }
            }
        } else {
            guard Darwin.lseek(fd, 0, SEEK_END) >= 0 else {
                throw SuperDictateMemoryRecoveryJournalError.posix(errno)
            }
            try writeRecoveryBytes(Data([UInt8(ascii: "\n")]), fd: fd)
        }
        guard Darwin.fsync(fd) == 0 else {
            throw SuperDictateMemoryRecoveryJournalError.posix(errno)
        }
    }

    private static func writeRecoveryBytes(_ data: Data, fd: Int32) throws {
        try data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var offset = 0
            while offset < raw.count {
                let result = Darwin.write(fd, base.advanced(by: offset), raw.count - offset)
                if result < 0 {
                    if errno == EINTR { continue }
                    throw SuperDictateMemoryRecoveryJournalError.posix(errno)
                }
                guard result > 0 else {
                    throw SuperDictateMemoryRecoveryJournalError.posix(EIO)
                }
                offset += result
            }
        }
    }

    private static func readRecoveryBytes(_ url: URL, maximumBytes: Int) throws -> Data {
        let fd = Darwin.open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else {
            if errno == ELOOP { throw SuperDictateMemoryRecoveryJournalError.unsafeFileType }
            throw SuperDictateMemoryRecoveryJournalError.posix(errno)
        }
        defer { _ = Darwin.close(fd) }

        var st = stat()
        guard Darwin.fstat(fd, &st) == 0 else {
            throw SuperDictateMemoryRecoveryJournalError.posix(errno)
        }
        guard (st.st_mode & S_IFMT) == S_IFREG,
              st.st_nlink == 1 else {
            throw SuperDictateMemoryRecoveryJournalError.unsafeFileType
        }
        guard st.st_size >= 0,
              st.st_size <= off_t(maximumBytes) else {
            throw SuperDictateMemoryRecoveryJournalError.fileTooLarge(
                Int(max(0, st.st_size)),
                maximumBytes
            )
        }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
        while true {
            let count = buffer.withUnsafeMutableBytes {
                Darwin.read(fd, $0.baseAddress, $0.count)
            }
            if count < 0 {
                if errno == EINTR { continue }
                throw SuperDictateMemoryRecoveryJournalError.posix(errno)
            }
            guard count > 0 else { break }
            guard data.count + count <= maximumBytes else {
                throw SuperDictateMemoryRecoveryJournalError.fileTooLarge(
                    data.count + count,
                    maximumBytes
                )
            }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }
}
