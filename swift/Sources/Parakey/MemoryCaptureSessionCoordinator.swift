import Foundation
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
    let chunks: [SuperDictateMemoryAudioChunk]

    var durationMilliseconds: Int64 {
        chunks.map(\.sessionEndMilliseconds).max() ?? 0
    }
}

/// First production coordinator for long-form Memory Capture.
///
/// This v1 intentionally owns only the microphone source. The package and chunk
/// contracts already support a separate `.system` track, and the host-time anchor
/// is allocated before capture so future ScreenCaptureKit audio can share the same
/// real session timeline without mixing source files.
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
    private var readyResult: MemoryCaptureSessionResult?

    init(store: JSONSuperDictateMemoryPackageStore) {
        self.store = store
    }

    var activeRecordingID: UUID? {
        lifecycle == .recording ? recordingID : nil
    }

    func start() async throws -> UUID {
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
        let writer = MemoryCAFChunkWriter(
            recordingID: recordingID,
            source: .microphone,
            committer: committer
        )
        let microphone = MemoryMicrophoneCaptureAdapter(
            writer: writer,
            clockAnchor: clockAnchor
        )

        self.recordingID = recordingID
        self.createdAt = createdAt
        self.clockAnchor = clockAnchor
        self.microphone = microphone

        do {
            try await microphone.start()
            lifecycle = .recording
            return recordingID
        } catch {
            _ = try? await store.markNeedsAttention(
                recordingID: recordingID,
                message: "Memory Capture microphone source could not start."
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
            let chunks = try await microphone.stop()
            guard !chunks.isEmpty else {
                throw MemoryCaptureSessionCoordinatorError.noSourceAudio
            }

            _ = try await store.beginFinalization(recordingID: recordingID)
            _ = try await store.markReady(recordingID: recordingID)

            let result = MemoryCaptureSessionResult(
                recordingID: recordingID,
                createdAt: createdAt,
                chunks: chunks
            )
            readyResult = result
            self.microphone = nil
            lifecycle = .ready
            return result
        } catch {
            _ = try? await store.markNeedsAttention(
                recordingID: recordingID,
                message: "Memory Capture microphone source requires recovery."
            )
            self.microphone = nil
            lifecycle = .needsAttention
            throw error
        }
    }
}
