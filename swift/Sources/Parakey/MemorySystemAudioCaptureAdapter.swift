import CoreMedia
import Foundation
import ScreenCaptureKit
import SuperDictateCore

private enum MemorySystemAudioCaptureFailure: Error, Equatable, Sendable {
    case alreadyStarted
    case invalidPresentationTimestamp
    case pcmCopyFailed
    case streamBackpressure
    case writerFailed
    case streamStopped
}

private final class MemorySystemAudioFailureBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: MemorySystemAudioCaptureFailure?

    func record(_ failure: MemorySystemAudioCaptureFailure) {
        lock.lock()
        defer { lock.unlock() }
        if stored == nil {
            stored = failure
        }
    }

    func value() -> MemorySystemAudioCaptureFailure? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}

/// Converts ScreenCaptureKit presentation timestamps into one source-local
/// monotonic timeline. System audio and microphone remain separate tracks, so
/// their clocks are intentionally not mixed at storage time.
private final class MemorySystemAudioTimeline: @unchecked Sendable {
    private let lock = NSLock()
    private var firstSeconds: Double?
    private var lastMilliseconds: Int64 = 0

    func startMilliseconds(
        presentationTime: CMTime
    ) throws -> Int64 {
        guard presentationTime.isValid,
              presentationTime.isNumeric else {
            throw MemorySystemAudioCaptureFailure.invalidPresentationTimestamp
        }
        let seconds = CMTimeGetSeconds(presentationTime)
        guard seconds.isFinite else {
            throw MemorySystemAudioCaptureFailure.invalidPresentationTimestamp
        }

        lock.lock()
        defer { lock.unlock() }
        if firstSeconds == nil {
            firstSeconds = seconds
        }
        guard let firstSeconds else {
            throw MemorySystemAudioCaptureFailure.invalidPresentationTimestamp
        }
        let relativeSeconds = seconds - firstSeconds
        guard relativeSeconds >= -0.000_5 else {
            throw MemorySystemAudioCaptureFailure.invalidPresentationTimestamp
        }
        let milliseconds = max(
            0,
            Int64((relativeSeconds * 1_000.0).rounded())
        )
        // Timestamp rounding can map adjacent callbacks to the same millisecond,
        // but time must never move backwards.
        let monotonic = max(lastMilliseconds, milliseconds)
        lastMilliseconds = monotonic
        return monotonic
    }
}

/// ScreenCaptureKit callback object. The callback stays on its dedicated serial
/// queue and synchronously copies CMSampleBuffer bytes before returning; the
/// CoreMedia buffer never crosses into the async writer actor.
private final class MemorySystemAudioOutput: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private let continuation: AsyncStream<SuperDictateMemoryPCMBlock>.Continuation
    private let failureBox: MemorySystemAudioFailureBox
    private let timeline = MemorySystemAudioTimeline()

    init(
        continuation: AsyncStream<SuperDictateMemoryPCMBlock>.Continuation,
        failureBox: MemorySystemAudioFailureBox
    ) {
        self.continuation = continuation
        self.failureBox = failureBox
        super.init()
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .audio,
              CMSampleBufferIsValid(sampleBuffer) else {
            return
        }

        let startMilliseconds: Int64
        do {
            startMilliseconds = try timeline.startMilliseconds(
                presentationTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            )
        } catch {
            failureBox.record(.invalidPresentationTimestamp)
            continuation.finish()
            return
        }

        let block: SuperDictateMemoryPCMBlock
        do {
            block = try MemorySystemSampleBufferCopy.makeBlock(
                from: sampleBuffer,
                sessionStartMilliseconds: startMilliseconds
            )
        } catch {
            failureBox.record(.pcmCopyFailed)
            continuation.finish()
            return
        }

        switch continuation.yield(block) {
        case .enqueued:
            break
        case .dropped:
            failureBox.record(.streamBackpressure)
            continuation.finish()
        case .terminated:
            break
        @unknown default:
            failureBox.record(.streamBackpressure)
            continuation.finish()
        }
    }

    func stream(
        _ stream: SCStream,
        didStopWithError error: Error
    ) {
        failureBox.record(.streamStopped)
        continuation.finish()
    }
}

/// Independent long-form system-audio source for Memory Capture.
///
/// The caller must provide an `SCContentFilter` selected by the system picker or
/// another explicit user flow. This adapter never chooses a display/window by
/// itself. It captures only the `.audio` output at 48 kHz stereo, excludes this
/// process's audio, and writes a separate `.system` source track.
@MainActor
final class MemorySystemAudioCaptureAdapter {
    private enum Lifecycle {
        case idle
        case running
        case finished
        case failed
    }

    private let writer: MemoryCAFChunkWriter
    private let contentFilter: SCContentFilter
    private let callbackQueue = DispatchQueue(
        label: "com.local.superdictate.memory.system-audio",
        qos: .userInitiated
    )

    private var lifecycle: Lifecycle = .idle
    private var stream: SCStream?
    private var output: MemorySystemAudioOutput?
    private var continuation: AsyncStream<SuperDictateMemoryPCMBlock>.Continuation?
    private var consumerTask: Task<Void, Never>?
    private var failureBox: MemorySystemAudioFailureBox?
    private var finalChunks: [SuperDictateMemoryAudioChunk] = []
    private var terminalFailure: MemorySystemAudioCaptureFailure?

    init(
        contentFilter: SCContentFilter,
        writer: MemoryCAFChunkWriter
    ) {
        self.contentFilter = contentFilter
        self.writer = writer
    }

    func start() async throws {
        guard lifecycle == .idle else {
            throw MemorySystemAudioCaptureFailure.alreadyStarted
        }

        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.sampleRate = 48_000
        configuration.channelCount = 2
        configuration.excludesCurrentProcessAudio = true

        let pair = AsyncStream.makeStream(
            of: SuperDictateMemoryPCMBlock.self,
            bufferingPolicy: .bufferingOldest(64)
        )
        let streamValues = pair.stream
        let continuation = pair.continuation
        let failureBox = MemorySystemAudioFailureBox()
        let output = MemorySystemAudioOutput(
            continuation: continuation,
            failureBox: failureBox
        )
        let stream = SCStream(
            filter: contentFilter,
            configuration: configuration,
            delegate: output
        )

        try stream.addStreamOutput(
            output,
            type: .audio,
            sampleHandlerQueue: callbackQueue
        )

        self.stream = stream
        self.output = output
        self.continuation = continuation
        self.failureBox = failureBox
        consumerTask = Task { [writer] in
            for await block in streamValues {
                do {
                    try await writer.append(block)
                } catch {
                    failureBox.record(.writerFailed)
                    await writer.abandonForRecovery()
                    continuation.finish()
                    break
                }
            }
        }

        do {
            try await startCapture(stream)
            lifecycle = .running
        } catch {
            try? stream.removeStreamOutput(output, type: .audio)
            continuation.finish()
            await consumerTask?.value
            await writer.abandonForRecovery()
            self.stream = nil
            self.output = nil
            self.continuation = nil
            self.consumerTask = nil
            self.failureBox = nil
            terminalFailure = .streamStopped
            lifecycle = .failed
            throw error
        }
    }

    @discardableResult
    func stop() async throws -> [SuperDictateMemoryAudioChunk] {
        switch lifecycle {
        case .idle:
            return []
        case .finished:
            return finalChunks
        case .failed:
            throw terminalFailure ?? .streamStopped
        case .running:
            break
        }

        if let stream {
            do {
                try await stopCapture(stream)
            } catch {
                failureBox?.record(.streamStopped)
            }
            if let output {
                try? stream.removeStreamOutput(output, type: .audio)
            }
        }

        continuation?.finish()
        await consumerTask?.value

        self.stream = nil
        self.output = nil
        self.continuation = nil
        self.consumerTask = nil
        let failure = failureBox?.value()
        self.failureBox = nil

        if let failure {
            await writer.abandonForRecovery()
            terminalFailure = failure
            lifecycle = .failed
            throw failure
        }

        do {
            finalChunks = try await writer.finish()
            lifecycle = .finished
            return finalChunks
        } catch {
            terminalFailure = .writerFailed
            lifecycle = .failed
            throw error
        }
    }

    private func startCapture(_ stream: SCStream) async throws {
        try await withCheckedThrowingContinuation { continuation in
            stream.startCapture { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func stopCapture(_ stream: SCStream) async throws {
        try await withCheckedThrowingContinuation { continuation in
            stream.stopCapture { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
