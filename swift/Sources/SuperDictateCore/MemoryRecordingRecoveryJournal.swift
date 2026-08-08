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
    /// Nil for `.chunkPrepared`; mandatory for `.chunkCommitted`.
    /// This binds a committed source to the exact finalized bytes even if the
    /// manifest descriptor is later lost and recovery must reconstruct it.
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
              byteLength > 0 else {
            throw SuperDictateMemoryRecoveryJournalError.invalidMetadata
        }
        guard sampleRate > 0,
              channelCount == 1 || channelCount == 2 else {
            throw SuperDictateMemoryRecoveryJournalError.invalidMetadata
        }
        let path = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let canonicalPath = SuperDictateMemoryAudioChunk.canonicalRelativePath(
            source: source,
            sequence: sequence,
            chunkID: chunkID,
            container: container
        )
        guard path == canonicalPath else {
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
                  Self.isValidSHA256(normalizedSHA) else {
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

    private static func isValidSHA256(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }
}

public enum SuperDictateMemoryRecoveryJournalError: Error, Equatable, Sendable {
    case unsupportedSchema(Int)
    case invalidMetadata
    case invalidRelativePath(String)
    case invalidSHA256(String)
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

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        var line = try encoder.encode(event)
        line.append(UInt8(ascii: "\n"))

        let url = recoveryJournalURL(recordingID: event.recordingID)
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
        try Self.writeRecoveryJournalBytes(line, fd: fd)
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
        guard FileManager.default.fileExists(atPath: url.path) else {
            return SuperDictateMemoryRecoveryJournalSnapshot(events: [])
        }
        let data = try Self.readRecoveryJournalBytes(
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
                events.append(event)
            } catch {
                let isLastPhysicalLine = index == lines.count - 1
                let hasTrailingNewline = data.last == UInt8(ascii: "\n")
                if isLastPhysicalLine && !hasTrailingNewline {
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

    private static func writeRecoveryJournalBytes(_ data: Data, fd: Int32) throws {
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

    private static func readRecoveryJournalBytes(_ url: URL, maximumBytes: Int) throws -> Data {
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
