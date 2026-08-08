import AVFoundation
import Foundation
import SuperDictateCore

private enum MemoryMicrophoneCaptureFailure: Error, Equatable, Sendable {
    case alreadyStarted
    case invalidInputChannelCount(Int)
    case invalidInputFormat
    case pcmCopyFailed
    case streamBackpressure
    case writerFailed
    case captureFailed
}

private final class MemoryMicrophoneFailureBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: MemoryMicrophoneCaptureFailure?

    func record(_ failure: MemoryMicrophoneCaptureFailure) {
        lock.lock()
        defer { lock.unlock() }
        if stored == nil {
            stored = failure
        }
    }

    func value() -> MemoryMicrophoneCaptureFailure? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}

private final class MemoryMicrophoneTimeline: @unchecked Sendable {
    private let lock = NSLock()
    private var firstSampleTime: AVAudioFramePosition?
    private var fallbackFramePosition: Int64 = 0

    func startMilliseconds(
        when: AVAudioTime,
        frameCount: Int,
        sampleRate: Double
    ) -> Int64 {
        lock.lock()
        defer { lock.unlock() }

        var startFrame = fallbackFramePosition
        if when.isSampleTimeValid {
            if firstSampleTime == nil {
                firstSampleTime = when.sampleTime
            }
            if let firstSampleTime {
                let delta = when.sampleTime - firstSampleTime
                if delta >= 0 {
                    startFrame = max(startFrame, Int64(delta))
                }
            }
        }
        fallbackFramePosition = startFrame + Int64(frameCount)
        return Int64(
            (Double(startFrame) / sampleRate * 1_000.0)
                .rounded()
        )
    }
}

/// Independent long-form microphone source for Memory Capture.
///
/// This intentionally does not reuse or modify Instant Dictation's `AudioCapture`.
/// The existing hotkey/ASR path keeps its proven callback/converter behavior. This
/// adapter exists only for future Memory sessions and writes through the
/// crash-safe Memory package transaction.
@MainActor
final class MemoryMicrophoneCaptureAdapter {
    private enum Lifecycle {
        case idle
        case running
        case finished
        case failed
    }

    private let engine: AVAudioEngine
    private let writer: MemoryCAFChunkWriter

    private var lifecycle: Lifecycle = .idle
    private var continuation: AsyncStream<SuperDictateMemoryPCMBlock>.Continuation?
    private var consumerTask: Task<Void, Never>?
    private var failureBox: MemoryMicrophoneFailureBox?
    private var finalChunks: [SuperDictateMemoryAudioChunk] = []
    private var terminalFailure: MemoryMicrophoneCaptureFailure?

    init(
        writer: MemoryCAFChunkWriter,
        engine: AVAudioEngine = AVAudioEngine()
    ) {
        self.writer = writer
        self.engine = engine
    }

    func start() async throws {
        guard lifecycle == .idle else {
            throw MemoryMicrophoneCaptureFailure.alreadyStarted
        }

        let input = engine.inputNode
        let sourceFormat = input.outputFormat(forBus: 0)
        let channelCount = Int(sourceFormat.channelCount)
        guard channelCount == 1 || channelCount == 2 else {
            throw MemoryMicrophoneCaptureFailure.invalidInputChannelCount(channelCount)
        }
        guard sourceFormat.sampleRate.isFinite,
              sourceFormat.sampleRate > 0,
              abs(sourceFormat.sampleRate - sourceFormat.sampleRate.rounded()) < 0.000_001,
              let tapFormat = AVAudioFormat(
                  commonFormat: .pcmFormatFloat32,
                  sampleRate: sourceFormat.sampleRate,
                  channels: sourceFormat.channelCount,
                  interleaved: false
              ) else {
            throw MemoryMicrophoneCaptureFailure.invalidInputFormat
        }

        let pair = AsyncStream.makeStream(
            of: SuperDictateMemoryPCMBlock.self,
            bufferingPolicy: .bufferingOldest(64)
        )
        let stream = pair.stream
        let continuation = pair.continuation
        let failureBox = MemoryMicrophoneFailureBox()
        let timeline = MemoryMicrophoneTimeline()

        self.continuation = continuation
        self.failureBox = failureBox
        consumerTask = Task { [writer] in
            for await block in stream {
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

        input.installTap(
            onBus: 0,
            bufferSize: 4_096,
            format: tapFormat
        ) { buffer, when in
            let startMilliseconds = timeline.startMilliseconds(
                when: when,
                frameCount: Int(buffer.frameLength),
                sampleRate: buffer.format.sampleRate
            )

            let block: SuperDictateMemoryPCMBlock
            do {
                block = try MemoryPCMBufferCopy.makeBlock(
                    from: buffer,
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

        do {
            engine.prepare()
            try engine.start()
            lifecycle = .running
        } catch {
            input.removeTap(onBus: 0)
            continuation.finish()
            await consumerTask?.value
            await writer.abandonForRecovery()
            self.continuation = nil
            self.consumerTask = nil
            self.failureBox = nil
            terminalFailure = .captureFailed
            lifecycle = .failed
            throw error
        }
    }

    /// Stop capture, drain every accepted callback block and finalize the last
    /// CAF only when the bounded pipeline remained healthy. A second stop after a
    /// successful finish is idempotent; a failed session remains failed.
    @discardableResult
    func stop() async throws -> [SuperDictateMemoryAudioChunk] {
        switch lifecycle {
        case .idle:
            return []
        case .finished:
            return finalChunks
        case .failed:
            throw terminalFailure ?? .captureFailed
        case .running:
            break
        }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        continuation?.finish()
        await consumerTask?.value

        continuation = nil
        consumerTask = nil
        let failure = failureBox?.value()
        failureBox = nil

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
}
