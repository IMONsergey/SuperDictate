import Foundation

public enum SuperDictateMemoryAudioSource: String, Codable, CaseIterable, Sendable {
    case microphone
    case system
    case imported
}

public enum SuperDictateMemorySessionState: String, Codable, Sendable {
    case recording
    case finalizing
    case ready
    case needsAttention = "needs_attention"
}

public enum SuperDictateMemoryManifestError: Error, Equatable, Sendable {
    case invalidRecordingID
    case invalidChunkPath(String)
    case invalidSHA256(String)
    case invalidTiming
    case invalidAudioFormat
    case invalidByteLength(Int64)
    case duplicateChunk(UUID)
    case duplicateSequence(source: SuperDictateMemoryAudioSource, sequence: Int)
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
    public var sampleRate: Int
    public var channelCount: Int
    public var byteLength: Int64
    public var sha256: String

    public init(
        id: UUID = UUID(),
        source: SuperDictateMemoryAudioSource,
        sequence: Int,
        relativePath: String,
        sessionStartMilliseconds: Int64,
        sessionEndMilliseconds: Int64,
        sampleRate: Int,
        channelCount: Int,
        byteLength: Int64,
        sha256: String
    ) throws {
        let path = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isSafeRelativePath(path) else {
            throw SuperDictateMemoryManifestError.invalidChunkPath(relativePath)
        }
        let digest = sha256.lowercased()
        guard digest.count == 64,
              digest.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) else {
            throw SuperDictateMemoryManifestError.invalidSHA256(sha256)
        }
        guard sequence >= 0,
              sessionStartMilliseconds >= 0,
              sessionEndMilliseconds >= sessionStartMilliseconds else {
            throw SuperDictateMemoryManifestError.invalidTiming
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
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.byteLength = byteLength
        self.sha256 = digest
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
    public var state: SuperDictateMemorySessionState
    public var chunks: [SuperDictateMemoryAudioChunk]
    public var issue: String?

    public init(
        recordingID: UUID,
        createdAt: Date,
        state: SuperDictateMemorySessionState = .recording,
        chunks: [SuperDictateMemoryAudioChunk] = [],
        issue: String? = nil
    ) throws {
        self.recordingID = recordingID
        self.createdAt = createdAt
        self.state = state
        self.chunks = chunks
        let trimmedIssue = issue?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.issue = trimmedIssue?.isEmpty == false ? trimmedIssue : nil
        try validate()
    }

    public mutating func appendFinalizedChunk(_ chunk: SuperDictateMemoryAudioChunk) throws {
        chunks.append(chunk)
        do {
            try validate()
        } catch {
            chunks.removeLast()
            throw error
        }
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
}
