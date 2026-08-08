import Foundation

public enum SuperDictateMemoryAudioSource: String, Codable, CaseIterable, Sendable {
    case microphone
    case system
    case imported
}

public enum SuperDictateMemoryAudioContainer: String, Codable, Sendable {
    case caf
}

public enum SuperDictateMemoryAudioCodec: String, Codable, Sendable {
    case linearPCM = "linear_pcm"
}

public enum SuperDictateMemorySessionState: String, Codable, Sendable {
    case recording
    case finalizing
    case ready
    case needsAttention = "needs_attention"
}

public enum SuperDictateMemoryManifestError: Error, Equatable, Sendable {
    case invalidChunkPath(String)
    case invalidSHA256(String)
    case invalidTiming
    case invalidAudioFormat
    case invalidByteLength(Int64)
    case duplicateChunk(UUID)
    case duplicateSequence(source: SuperDictateMemoryAudioSource, sequence: Int)
    case chunkAppendNotAllowed(SuperDictateMemorySessionState)
    case invalidStateTransition(from: SuperDictateMemorySessionState, to: SuperDictateMemorySessionState)
    case invalidIssueState
}

/// Immutable finalized source chunk referenced by a Memory Capture package.
/// A descriptor is created only after the backing file is closed, fsynced,
/// atomically finalized and hashed.
public struct SuperDictateMemoryAudioChunk: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var source: SuperDictateMemoryAudioSource
    public var sequence: Int
    public var relativePath: String
    public var sessionStartMilliseconds: Int64
    public var sessionEndMilliseconds: Int64
    public var container: SuperDictateMemoryAudioContainer
    public var codec: SuperDictateMemoryAudioCodec
    public var sampleRate: Int
    public var channelCount: Int
    public var byteLength: Int64
    public var sha256: String

    private enum CodingKeys: String, CodingKey {
        case id
        case source
        case sequence
        case relativePath
        case sessionStartMilliseconds
        case sessionEndMilliseconds
        case container
        case codec
        case sampleRate
        case channelCount
        case byteLength
        case sha256
    }

    public init(
        id: UUID = UUID(),
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
        sha256: String
    ) throws {
        let path = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sequence >= 0,
              sessionStartMilliseconds >= 0,
              sessionEndMilliseconds >= sessionStartMilliseconds else {
            throw SuperDictateMemoryManifestError.invalidTiming
        }
        guard Self.isSafeRelativePath(path),
              path == Self.canonicalRelativePath(
                  source: source,
                  sequence: sequence,
                  chunkID: id,
                  container: container
              ) else {
            throw SuperDictateMemoryManifestError.invalidChunkPath(relativePath)
        }
        let digest = sha256.lowercased()
        guard digest.count == 64,
              digest.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) else {
            throw SuperDictateMemoryManifestError.invalidSHA256(sha256)
        }
        guard sampleRate > 0,
              channelCount == 1 || channelCount == 2 else {
            throw SuperDictateMemoryManifestError.invalidAudioFormat
        }
        guard byteLength > 0 else {
            throw SuperDictateMemoryManifestError.invalidByteLength(byteLength)
        }

        self.id = id
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
        self.sha256 = digest
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(UUID.self, forKey: .id),
            source: container.decode(SuperDictateMemoryAudioSource.self, forKey: .source),
            sequence: container.decode(Int.self, forKey: .sequence),
            relativePath: container.decode(String.self, forKey: .relativePath),
            sessionStartMilliseconds: container.decode(Int64.self, forKey: .sessionStartMilliseconds),
            sessionEndMilliseconds: container.decode(Int64.self, forKey: .sessionEndMilliseconds),
            container: container.decode(SuperDictateMemoryAudioContainer.self, forKey: .container),
            codec: container.decode(SuperDictateMemoryAudioCodec.self, forKey: .codec),
            sampleRate: container.decode(Int.self, forKey: .sampleRate),
            channelCount: container.decode(Int.self, forKey: .channelCount),
            byteLength: container.decode(Int64.self, forKey: .byteLength),
            sha256: container.decode(String.self, forKey: .sha256)
        )
    }

    public static func canonicalRelativePath(
        source: SuperDictateMemoryAudioSource,
        sequence: Int,
        chunkID: UUID,
        container: SuperDictateMemoryAudioContainer = .caf
    ) -> String {
        let sequenceText = String(format: "%06d", max(0, sequence))
        return "audio/\(source.rawValue)/\(sequenceText)__\(chunkID.uuidString.lowercased()).\(container.rawValue)"
    }

    private static func isSafeRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.contains("\\") else {
            return false
        }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty else { return false }
        return components.allSatisfy { component in
            component != "." && component != ".." && !component.isEmpty
        }
    }
}

public struct SuperDictateMemoryRecordingManifest: Codable, Equatable, Sendable {
    public static let schemaVersion = 1

    public var recordingID: UUID
    public var createdAt: Date
    public private(set) var state: SuperDictateMemorySessionState
    public var chunks: [SuperDictateMemoryAudioChunk]
    public private(set) var issue: String?

    private enum CodingKeys: String, CodingKey {
        case recordingID
        case createdAt
        case state
        case chunks
        case issue
    }

    /// New source packages always begin in `.recording`. Restored packages may
    /// decode later states, but runtime code must use the explicit transition
    /// methods below rather than constructing an arbitrary lifecycle state.
    public init(
        recordingID: UUID,
        createdAt: Date,
        chunks: [SuperDictateMemoryAudioChunk] = []
    ) throws {
        try self.init(
            recordingID: recordingID,
            createdAt: createdAt,
            state: .recording,
            chunks: chunks,
            issue: nil
        )
    }

    private init(
        recordingID: UUID,
        createdAt: Date,
        state: SuperDictateMemorySessionState,
        chunks: [SuperDictateMemoryAudioChunk],
        issue: String?
    ) throws {
        self.recordingID = recordingID
        self.createdAt = createdAt
        self.state = state
        self.chunks = chunks
        self.issue = Self.normalizedIssue(issue)
        try validate()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            recordingID: container.decode(UUID.self, forKey: .recordingID),
            createdAt: container.decode(Date.self, forKey: .createdAt),
            state: container.decode(SuperDictateMemorySessionState.self, forKey: .state),
            chunks: container.decode([SuperDictateMemoryAudioChunk].self, forKey: .chunks),
            issue: container.decodeIfPresent(String.self, forKey: .issue)
        )
    }

    public mutating func appendFinalizedChunk(_ chunk: SuperDictateMemoryAudioChunk) throws {
        guard state == .recording || state == .finalizing else {
            throw SuperDictateMemoryManifestError.chunkAppendNotAllowed(state)
        }
        chunks.append(chunk)
        do {
            try validate()
        } catch {
            chunks.removeLast()
            throw error
        }
    }

    public mutating func beginFinalization() throws {
        guard state == .recording || state == .needsAttention else {
            throw SuperDictateMemoryManifestError.invalidStateTransition(
                from: state,
                to: .finalizing
            )
        }
        state = .finalizing
        issue = nil
    }

    public mutating func markReady() throws {
        guard state == .finalizing else {
            throw SuperDictateMemoryManifestError.invalidStateTransition(
                from: state,
                to: .ready
            )
        }
        state = .ready
        issue = nil
    }

    /// Operational attention cannot silently reopen a ready package. The Core
    /// recovery layer has a separate internal integrity transition below for
    /// physical checksum/missing-source failures discovered after finalization.
    public mutating func markNeedsAttention(_ message: String) throws {
        guard state != .ready else {
            throw SuperDictateMemoryManifestError.invalidStateTransition(
                from: state,
                to: .needsAttention
            )
        }
        try setNeedsAttention(message)
    }

    /// Core-only integrity transition. A package that was legitimately ready can
    /// later become unhealthy because source bytes are missing or corrupted. This
    /// method is intentionally internal so UI/adapters cannot use it to reopen a
    /// ready recording for ordinary writes.
    mutating func markIntegrityNeedsAttention(_ message: String) throws {
        try setNeedsAttention(message)
    }

    public func chunks(for source: SuperDictateMemoryAudioSource) -> [SuperDictateMemoryAudioChunk] {
        chunks
            .filter { $0.source == source }
            .sorted { lhs, rhs in
                if lhs.sequence != rhs.sequence { return lhs.sequence < rhs.sequence }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    public func validate() throws {
        switch state {
        case .needsAttention:
            guard issue != nil else {
                throw SuperDictateMemoryManifestError.invalidIssueState
            }
        case .recording, .finalizing, .ready:
            guard issue == nil else {
                throw SuperDictateMemoryManifestError.invalidIssueState
            }
        }

        var chunkIDs: Set<UUID> = []
        var sequences: [SuperDictateMemoryAudioSource: Set<Int>] = [:]

        for chunk in chunks {
            guard chunkIDs.insert(chunk.id).inserted else {
                throw SuperDictateMemoryManifestError.duplicateChunk(chunk.id)
            }
            var sourceSequences = sequences[chunk.source, default: []]
            guard sourceSequences.insert(chunk.sequence).inserted else {
                throw SuperDictateMemoryManifestError.duplicateSequence(
                    source: chunk.source,
                    sequence: chunk.sequence
                )
            }
            sequences[chunk.source] = sourceSequences
        }
    }

    private mutating func setNeedsAttention(_ message: String) throws {
        let normalized = Self.normalizedIssue(message)
        guard let normalized else {
            throw SuperDictateMemoryManifestError.invalidIssueState
        }
        state = .needsAttention
        issue = normalized
    }

    private static func normalizedIssue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
