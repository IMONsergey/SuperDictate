#if canImport(AVFoundation)
import AVFoundation
import Foundation

public enum AVFoundationChunkEngineError: Error, Equatable, Sendable {
    case emptyBufferSet
    case formatMismatch
    case unsupportedPCMFormat(String)
    case missingPCMChannelData
    case emptyEncodedChunk
    case engineAlreadyRunning
    case engineNotRunning
}

public struct AppleAudioFormatDescription: Codable, Equatable, Sendable {
    public let sampleRate: Double
    public let channelCount: Int
    public let commonFormat: String
    public let interleaved: Bool

    public init(
        sampleRate: Double,
        channelCount: Int,
        commonFormat: String,
        interleaved: Bool
    ) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.commonFormat = commonFormat
        self.interleaved = interleaved
    }
}

public struct AppleEncodedAudioChunk: Equatable, Sendable {
    public let data: Data
    public let format: AppleAudioFormatDescription
    public let frameCount: Int64
    public let durationMilliseconds: Int64
    public let rmsLevel: Float

    public init(
        data: Data,
        format: AppleAudioFormatDescription,
        frameCount: Int64,
        durationMilliseconds: Int64,
        rmsLevel: Float
    ) {
        self.data = data
        self.format = format
        self.frameCount = frameCount
        self.durationMilliseconds = durationMilliseconds
        self.rmsLevel = rmsLevel
    }
}

public enum AVFoundationPCMChunkEncoder {
    public static func encodeCAF(
        buffers: [AVAudioPCMBuffer],
        fileManager: FileManager = .default
    ) throws -> AppleEncodedAudioChunk {
        guard let first = buffers.first else {
            throw AVFoundationChunkEngineError.emptyBufferSet
        }
        guard first.frameLength > 0 else {
            throw AVFoundationChunkEngineError.emptyBufferSet
        }

        let format = first.format
        guard format.sampleRate > 0 else {
            throw AVFoundationChunkEngineError.unsupportedPCMFormat("invalid_sample_rate")
        }

        let writableBuffers = try buffers.filter { buffer in
            guard buffer.frameLength > 0 else { return false }
            guard buffer.format.isChunkCompatible(with: format) else {
                throw AVFoundationChunkEngineError.formatMismatch
            }
            return true
        }
        guard !writableBuffers.isEmpty else {
            throw AVFoundationChunkEngineError.emptyBufferSet
        }

        let tempURL = fileManager.temporaryDirectory
            .appendingPathComponent("SuperDictateCAF-\(UUID().uuidString)")
            .appendingPathExtension("caf")
        defer { try? fileManager.removeItem(at: tempURL) }

        let file = try AVAudioFile(
            forWriting: tempURL,
            settings: format.settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )

        var metrics = PCMLevelMetrics()
        var frameCount: Int64 = 0
        for buffer in writableBuffers {
            try metrics.append(buffer)
            try file.write(from: buffer)
            frameCount += Int64(buffer.frameLength)
        }

        let data = try Data(contentsOf: tempURL)
        guard !data.isEmpty else {
            throw AVFoundationChunkEngineError.emptyEncodedChunk
        }

        return AppleEncodedAudioChunk(
            data: data,
            format: AppleAudioFormatDescription(format),
            frameCount: frameCount,
            durationMilliseconds: Int64(
                (Double(frameCount) / format.sampleRate * 1_000).rounded()
            ),
            rmsLevel: metrics.rmsLevel
        )
    }
}

public actor AppleEncodedChunkRecorder {
    private let writer: any AppleAudioCaptureChunkWriting
    private let recordingID: UUID
    private let assetID: UUID
    private var nextSequence: Int

    public init(
        writer: any AppleAudioCaptureChunkWriting,
        recordingID: UUID,
        assetID: UUID = UUID(),
        startingSequence: Int = 0
    ) {
        self.writer = writer
        self.recordingID = recordingID
        self.assetID = assetID
        self.nextSequence = startingSequence
    }

    public func persist(
        _ chunk: AppleEncodedAudioChunk,
        chunkID: UUID = UUID(),
        at date: Date = Date()
    ) async throws -> AudioChunkDescriptor {
        guard !chunk.data.isEmpty else {
            throw AVFoundationChunkEngineError.emptyEncodedChunk
        }

        let sequence = nextSequence
        try await writer.openChunk(
            recordingID: recordingID,
            assetID: assetID,
            sequence: sequence,
            chunkID: chunkID,
            at: date
        )
        try await writer.write(chunk.data, to: recordingID, at: date)
        let descriptor = try await writer.closeChunk(
            recordingID: recordingID,
            durationMilliseconds: chunk.durationMilliseconds,
            at: date
        )
        nextSequence += 1
        return descriptor
    }

    public func currentSequence() -> Int {
        nextSequence
    }
}

public final class AVAudioEngineBufferTap: @unchecked Sendable {
    public typealias Handler = (AVAudioPCMBuffer, AVAudioTime) -> Void

    private let engine: AVAudioEngine
    private let bus: AVAudioNodeBus
    private let bufferSize: AVAudioFrameCount
    private let lock = NSLock()
    private var running = false

    public init(
        engine: AVAudioEngine = AVAudioEngine(),
        bus: AVAudioNodeBus = 0,
        bufferSize: AVAudioFrameCount = 4_096
    ) {
        self.engine = engine
        self.bus = bus
        self.bufferSize = bufferSize
    }

    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return running
    }

    public func start(handler: @escaping Handler) throws {
        lock.lock()
        guard !running else {
            lock.unlock()
            throw AVFoundationChunkEngineError.engineAlreadyRunning
        }
        running = true
        lock.unlock()

        let input = engine.inputNode
        let format = input.outputFormat(forBus: bus)
        input.installTap(
            onBus: bus,
            bufferSize: bufferSize,
            format: format
        ) { buffer, time in
            handler(buffer, time)
        }

        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: bus)
            lock.lock()
            running = false
            lock.unlock()
            throw error
        }
    }

    public func stop() throws {
        lock.lock()
        guard running else {
            lock.unlock()
            throw AVFoundationChunkEngineError.engineNotRunning
        }
        running = false
        lock.unlock()

        engine.inputNode.removeTap(onBus: bus)
        engine.stop()
        engine.reset()
    }
}

private extension AppleAudioFormatDescription {
    init(_ format: AVAudioFormat) {
        self.init(
            sampleRate: format.sampleRate,
            channelCount: Int(format.channelCount),
            commonFormat: String(describing: format.commonFormat),
            interleaved: format.isInterleaved
        )
    }
}

private extension AVAudioFormat {
    func isChunkCompatible(with other: AVAudioFormat) -> Bool {
        sampleRate == other.sampleRate
            && channelCount == other.channelCount
            && commonFormat == other.commonFormat
            && isInterleaved == other.isInterleaved
    }
}

private struct PCMLevelMetrics {
    private var sumSquares = 0.0
    private var sampleCount = 0

    var rmsLevel: Float {
        guard sampleCount > 0 else { return 0 }
        return Float(min(1, sqrt(sumSquares / Double(sampleCount))))
    }

    mutating func append(_ buffer: AVAudioPCMBuffer) throws {
        switch buffer.format.commonFormat {
        case .pcmFormatFloat32:
            try appendFloat32(buffer)
        case .pcmFormatInt16:
            try appendInt16(buffer)
        case .pcmFormatInt32:
            try appendInt32(buffer)
        default:
            throw AVFoundationChunkEngineError.unsupportedPCMFormat(
                String(describing: buffer.format.commonFormat)
            )
        }
    }

    private mutating func appendFloat32(_ buffer: AVAudioPCMBuffer) throws {
        guard let channels = buffer.floatChannelData else {
            throw AVFoundationChunkEngineError.missingPCMChannelData
        }
        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)
        for channelIndex in 0..<channelCount {
            let channel = channels[channelIndex]
            for frameIndex in 0..<frameCount {
                let sample = channel[frameIndex]
                guard sample.isFinite else { continue }
                let clamped = max(-1, min(1, sample))
                sumSquares += Double(clamped * clamped)
                sampleCount += 1
            }
        }
    }

    private mutating func appendInt16(_ buffer: AVAudioPCMBuffer) throws {
        guard let channels = buffer.int16ChannelData else {
            throw AVFoundationChunkEngineError.missingPCMChannelData
        }
        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)
        for channelIndex in 0..<channelCount {
            let channel = channels[channelIndex]
            for frameIndex in 0..<frameCount {
                let sample = Float(channel[frameIndex]) / Float(Int16.max)
                sumSquares += Double(sample * sample)
                sampleCount += 1
            }
        }
    }

    private mutating func appendInt32(_ buffer: AVAudioPCMBuffer) throws {
        guard let channels = buffer.int32ChannelData else {
            throw AVFoundationChunkEngineError.missingPCMChannelData
        }
        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)
        for channelIndex in 0..<channelCount {
            let channel = channels[channelIndex]
            for frameIndex in 0..<frameCount {
                let sample = Float(channel[frameIndex]) / Float(Int32.max)
                sumSquares += Double(sample * sample)
                sampleCount += 1
            }
        }
    }
}
#endif
