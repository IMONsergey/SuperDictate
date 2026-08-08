import AVFoundation
import Foundation
import SuperDictateCore

private enum MemoryMicrophoneCaptureFailure: Error, Equatable, Sendable {
    case alreadyStarted
    case invalidInputChannelCount(Int)
    case invalidInputFormat
    case invalidHostTime
    case pcmCopyFailed
    case streamBackpressure
    case writerFailed
    case captureFailed
    case aborted
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
    private let clockAnchor: MemoryCaptureClockAnchor

    private var lifecycle: Lifecycle = .idle
    private var continuation: AsyncStream<SuperDictateMemoryPCMBlock>.Continuation?
    private var consumerTask: Task<Void, Never>?
    private var failureBox: MemoryMicrophoneFailureBox?
    private var finalChunks: [SuperDictateMemoryAudioChunk] = []
    private var terminalFailure: MemoryMicrophoneCaptureFailure?

    init(
        writer: MemoryCAFChunkWriter,
        clockAnchor: MemoryCaptureClockAnchor,
        engine: AVAudioEngine = AVAudioEngine()
    ) {
        self.writer = writer
        self.clockAnchor = clockAnchor
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
        let clockAnchor = self.clockAnchor

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
            guard when.isHostTimeValid else {
                failureBox.record(.invalidHostTime)
                continuation.finish()
                return
            }

            let startMilliseconds: Int64
            do {
                startMilliseconds = try clockAnchor.milliseconds(
                    atHostTime: when.hostTime
                )
            } catch {
                failureBox.record(.invalidHostTime)
                continuation.finish()
                return
            }

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
            clearStreamingState()
            terminalFailure = .captureFailed
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
            throw terminalFailure ?? .captureFailed
        case .running:
            break
        }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        continuation?.finish()
        await consumerTask?.value

        let failure = failureBox?.value()
        clearStreamingState()

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

    /// Abort a partially started/running source without promoting the current CAF
    /// to a finalized manifest chunk. Any `.partial` bytes stay in the package so
    /// source recovery can quarantine/inspect them. Used when another required
    /// track fails during a multi-source session startup.
    func abortForRecovery() async {
        guard lifecycle == .running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        continuation?.finish()
        await consumerTask?.value
        await writer.abandonForRecovery()
        clearStreamingState()
        terminalFailure = .aborted
        lifecycle = .failed
    }

    private func clearStreamingState() {
        continuation = nil
        consumerTask = nil
        failureBox = nil
    }
}
