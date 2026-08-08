import AVFoundation
import Foundation
import SuperDictateCore

public enum MemoryCAFChunkWriterError: Error, Equatable, Sendable {
    case nonMonotonicTimeline(previousEndMilliseconds: Int64, nextStartMilliseconds: Int64)
    case bufferAllocationFailed
    case unsupportedPCMBuffer
    case missingOpenChunkState
}

/// Serializes copied PCM callback blocks into immutable source-native CAF chunks.
///
/// This actor is deliberately independent from Instant Dictation's `AudioCapture`.
/// Capture adapters copy AVAudioPCMBuffer/ScreenCaptureKit callbacks into the
/// Sendable `SuperDictateMemoryPCMBlock`, then call `append`. No non-Sendable AV
/// buffer crosses the actor boundary and the proven dictation capture path stays
/// untouched.
actor MemoryCAFChunkWriter {
    private struct FormatKey: Equatable, Sendable {
        let sampleRate: Double
        let channelCount: Int
    }

    private let recordingID: UUID
    private let source: SuperDictateMemoryAudioSource
    private let committer: SuperDictateMemoryAudioChunkCommitter
    private let targetChunkMilliseconds: Int64

    private var nextSequence = 0
    private var currentSequence: Int?
    private var currentChunkID: UUID?
    private var currentTemporaryURL: URL?
    private var currentFile: AVAudioFile?
    private var currentFormat: AVAudioFormat?
    private var currentFormatKey: FormatKey?
    private var currentStartMilliseconds: Int64?
    private var currentEndMilliseconds: Int64?
    private var lastBlockEndMilliseconds: Int64?
    private var committedChunks: [SuperDictateMemoryAudioChunk] = []

    init(
        recordingID: UUID,
        source: SuperDictateMemoryAudioSource,
        committer: SuperDictateMemoryAudioChunkCommitter,
        targetChunkMilliseconds: Int64 = 30_000
    ) {
        self.recordingID = recordingID
        self.source = source
        self.committer = committer
        self.targetChunkMilliseconds = max(1_000, targetChunkMilliseconds)
    }

    /// Append one source callback copy. Gaps are allowed because callbacks from
    /// different capture APIs can have scheduling jitter; time may never move
    /// backwards. A source-format change closes the current immutable chunk and
    /// starts a new one instead of silently converting the authoritative audio.
    func append(_ block: SuperDictateMemoryPCMBlock) async throws {
        if let previousEnd = lastBlockEndMilliseconds,
           block.sessionStartMilliseconds < previousEnd {
            throw MemoryCAFChunkWriterError.nonMonotonicTimeline(
                previousEndMilliseconds: previousEnd,
                nextStartMilliseconds: block.sessionStartMilliseconds
            )
        }

        let incomingFormat = FormatKey(
            sampleRate: block.sampleRate,
            channelCount: block.channelCount
        )

        if let currentFormatKey,
           currentFormatKey != incomingFormat {
            try await finalizeCurrentChunk()
        } else if let start = currentStartMilliseconds,
                  let end = currentEndMilliseconds,
                  end - start >= targetChunkMilliseconds {
            try await finalizeCurrentChunk()
        }

        if currentFile == nil {
            try await openChunk(for: block)
        }
        try write(block)

        currentEndMilliseconds = block.sessionEndMilliseconds
        lastBlockEndMilliseconds = block.sessionEndMilliseconds

        if let start = currentStartMilliseconds,
           block.sessionEndMilliseconds - start >= targetChunkMilliseconds {
            try await finalizeCurrentChunk()
        }
    }

    /// Finalize the active chunk and return every descriptor successfully made
    /// authoritative in the package manifest during this writer lifetime.
    func finish() async throws -> [SuperDictateMemoryAudioChunk] {
        try await finalizeCurrentChunk()
        return committedChunks
    }

    var committedChunkCount: Int {
        committedChunks.count
    }

    private func openChunk(
        for block: SuperDictateMemoryPCMBlock
    ) async throws {
        let sequence = nextSequence
        let chunkID = UUID()
        let temporaryURL = try await committer.temporaryChunkURL(
            recordingID: recordingID,
            source: source,
            sequence: sequence,
            chunkID: chunkID
        )

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: block.sampleRate,
            channels: AVAudioChannelCount(block.channelCount),
            interleaved: false
        ) else {
            throw MemoryCAFChunkWriterError.unsupportedPCMBuffer
        }

        let file = try AVAudioFile(
            forWriting: temporaryURL,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )

        nextSequence += 1
        currentSequence = sequence
        currentChunkID = chunkID
        currentTemporaryURL = temporaryURL
        currentFile = file
        currentFormat = format
        currentFormatKey = FormatKey(
            sampleRate: block.sampleRate,
            channelCount: block.channelCount
        )
        currentStartMilliseconds = block.sessionStartMilliseconds
        currentEndMilliseconds = block.sessionStartMilliseconds
    }

    private func write(
        _ block: SuperDictateMemoryPCMBlock
    ) throws {
        guard let file = currentFile,
              let format = currentFormat else {
            throw MemoryCAFChunkWriterError.missingOpenChunkState
        }

        let frameCount = AVAudioFrameCount(block.frameCount)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        ) else {
            throw MemoryCAFChunkWriterError.bufferAllocationFailed
        }
        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData else {
            throw MemoryCAFChunkWriterError.unsupportedPCMBuffer
        }

        for channelIndex in 0..<block.channelCount {
            block.channels[channelIndex].withUnsafeBytes { sourceBytes in
                guard let sourceAddress = sourceBytes.baseAddress else { return }
                memcpy(
                    channelData[channelIndex],
                    sourceAddress,
                    block.frameCount * MemoryLayout<Float>.size
                )
            }
        }
        try file.write(from: buffer)
    }

    private func finalizeCurrentChunk() async throws {
        guard currentFile != nil else { return }
        guard let sequence = currentSequence,
              let chunkID = currentChunkID,
              let temporaryURL = currentTemporaryURL,
              let formatKey = currentFormatKey,
              let startMilliseconds = currentStartMilliseconds,
              let endMilliseconds = currentEndMilliseconds,
              endMilliseconds >= startMilliseconds else {
            throw MemoryCAFChunkWriterError.missingOpenChunkState
        }

        // Drop the final strong AVAudioFile reference before the committer opens
        // the file descriptor, ensuring AVFoundation has closed/flushed its CAF.
        currentFile = nil
        currentFormat = nil
        currentSequence = nil
        currentChunkID = nil
        currentTemporaryURL = nil
        currentFormatKey = nil
        currentStartMilliseconds = nil
        currentEndMilliseconds = nil

        let descriptor = try await committer.commitChunk(
            recordingID: recordingID,
            source: source,
            sequence: sequence,
            chunkID: chunkID,
            temporaryURL: temporaryURL,
            sessionStartMilliseconds: startMilliseconds,
            sessionEndMilliseconds: endMilliseconds,
            sampleRate: Int(formatKey.sampleRate.rounded()),
            channelCount: formatKey.channelCount
        )
        committedChunks.append(descriptor)
    }
}
