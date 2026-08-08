import Foundation
import ScreenCaptureKit
import SuperDictateCore

enum MemoryCaptureSessionCoordinatorError: Error, Equatable, Sendable {
    case sessionAlreadyStarted
    case sessionNotRecording
    case noSourceAudio
    case captureFailed
}

struct MemoryCaptureSessionResult: Equatable, Sendable {
    let recordingID: UUID
    let createdAt: Date
    let microphoneChunks: [SuperDictateMemoryAudioChunk]
    let systemChunks: [SuperDictateMemoryAudioChunk]

    var chunks: [SuperDictateMemoryAudioChunk] {
        (microphoneChunks + systemChunks).sorted { lhs, rhs in
            if lhs.sessionStartMilliseconds != rhs.sessionStartMilliseconds {
                return lhs.sessionStartMilliseconds < rhs.sessionStartMilliseconds
            }
            if lhs.source != rhs.source {
                return lhs.source.rawValue < rhs.source.rawValue
            }
            return lhs.sequence < rhs.sequence
        }
    }

    var durationMilliseconds: Int64 {
        chunks.map(\.sessionEndMilliseconds).max() ?? 0
    }

    var includesSystemAudio: Bool {
        !systemChunks.isEmpty
    }
}

/// Long-form Memory Capture coordinator over separate microphone/system source
/// tracks. It never mixes the tracks before storage and never touches Instant
/// Dictation's hotkey/AudioCapture path.
///
/// A single host-time anchor is created before either source starts. ScreenCapture
/// sample PTS values are converted through the SCStream synchronization clock;
/// microphone callbacks use AVAudioTime host time. Therefore both source manifests
/// share one real session timeline while preserving their original source files.
@MainActor
final class MemoryCaptureSessionCoordinator {
    private enum Lifecycle {
        case idle
        case recording
        case finalizing
        case ready
        case needsAttention
    }

    private let store: JSONSuperDictateMemoryPackageStore
    private var lifecycle: Lifecycle = .idle
    private var recordingID: UUID?
    private var createdAt: Date?
    private var clockAnchor: MemoryCaptureClockAnchor?
    private var microphone: MemoryMicrophoneCaptureAdapter?
    private var systemAudio: MemorySystemAudioCaptureAdapter?
    private var systemAudioRequested = false
    private var readyResult: MemoryCaptureSessionResult?

    init(store: JSONSuperDictateMemoryPackageStore) {
        self.store = store
    }

    var activeRecordingID: UUID? {
        lifecycle == .recording ? recordingID : nil
    }

    /// `systemAudioFilter == nil` creates a microphone-only Memory session.
    /// Supplying a filter makes system audio a required source for startup; the
    /// filter itself must come from explicit ScreenCaptureKit picker/user consent.
    func start(
        systemAudioFilter: SCContentFilter? = nil
    ) async throws -> UUID {
        guard lifecycle == .idle else {
            throw MemoryCaptureSessionCoordinatorError.sessionAlreadyStarted
        }

        let recordingID = UUID()
        let createdAt = Date()
        let clockAnchor = MemoryCaptureClockAnchor.now()
        _ = try await store.createPackage(
            recordingID: recordingID,
            createdAt: createdAt
        )

        let committer = SuperDictateMemoryAudioChunkCommitter(store: store)
        let microphoneWriter = MemoryCAFChunkWriter(
            recordingID: recordingID,
            source: .microphone,
            committer: committer
        )
        let microphone = MemoryMicrophoneCaptureAdapter(
            writer: microphoneWriter,
            clockAnchor: clockAnchor
        )

        let systemAudio: MemorySystemAudioCaptureAdapter?
        if let systemAudioFilter {
            let systemWriter = MemoryCAFChunkWriter(
                recordingID: recordingID,
                source: .system,
                committer: committer
            )
            systemAudio = MemorySystemAudioCaptureAdapter(
                contentFilter: systemAudioFilter,
                writer: systemWriter,
                clockAnchor: clockAnchor
            )
        } else {
            systemAudio = nil
        }

        self.recordingID = recordingID
        self.createdAt = createdAt
        self.clockAnchor = clockAnchor
        self.microphone = microphone
        self.systemAudio = systemAudio
        systemAudioRequested = systemAudio != nil

        do {
            // Start the permission-sensitive system source first. If it cannot
            // start, no microphone bytes have been captured yet.
            if let systemAudio {
                try await systemAudio.start()
            }

            do {
                try await microphone.start()
            } catch {
                await systemAudio?.abortForRecovery()
                throw error
            }

            lifecycle = .recording
            return recordingID
        } catch {
            _ = try? await store.markNeedsAttention(
                recordingID: recordingID,
                message: "Memory Capture source startup requires recovery."
            )
            lifecycle = .needsAttention
            throw error
        }
    }

    @discardableResult
    func stop() async throws -> MemoryCaptureSessionResult {
        if lifecycle == .ready,
           let readyResult {
            return readyResult
        }
        guard lifecycle == .recording,
              let recordingID,
              let createdAt,
              let microphone else {
            throw MemoryCaptureSessionCoordinatorError.sessionNotRecording
        }

        lifecycle = .finalizing
        do {
            let microphoneChunks: [SuperDictateMemoryAudioChunk]
            let systemChunks: [SuperDictateMemoryAudioChunk]

            if let systemAudio {
                // Structured concurrency lets each MainActor source synchronously
                // stop new delivery before either waits for its writer queue.
                async let microphoneResult = microphone.stop()
                async let systemResult = systemAudio.stop()
                (microphoneChunks, systemChunks) = try await (
                    microphoneResult,
                    systemResult
                )
            } else {
                microphoneChunks = try await microphone.stop()
                systemChunks = []
            }

            guard !microphoneChunks.isEmpty || !systemChunks.isEmpty else {
                throw MemoryCaptureSessionCoordinatorError.noSourceAudio
            }
            if systemAudioRequested,
               systemAudio != nil,
               systemChunks.isEmpty {
                // A requested remote/system source producing no finalized data is
                // ambiguous (permission/source failure vs real silence). Keep the
                // source package for inspection rather than claiming complete
                // dual-track capture.
                throw MemoryCaptureSessionCoordinatorError.noSourceAudio
            }

            _ = try await store.beginFinalization(recordingID: recordingID)
            _ = try await store.markReady(recordingID: recordingID)

            let result = MemoryCaptureSessionResult(
                recordingID: recordingID,
                createdAt: createdAt,
                microphoneChunks: microphoneChunks,
                systemChunks: systemChunks
            )
            readyResult = result
            clearSourceHandles()
            lifecycle = .ready
            return result
        } catch {
            await microphone.abortForRecovery()
            await systemAudio?.abortForRecovery()
            _ = try? await store.markNeedsAttention(
                recordingID: recordingID,
                message: "Memory Capture source requires recovery."
            )
            clearSourceHandles()
            lifecycle = .needsAttention
            throw error
        }
    }

    private func clearSourceHandles() {
        microphone = nil
        systemAudio = nil
        clockAnchor = nil
    }
}
