import Foundation

public enum RecordingLifecycleState: Equatable, Sendable {
    case idle
    case recording(startedAt: Date)
    case paused(startedAt: Date, pausedAt: Date)
    case finalizing
    case awaitingUpload
    case uploading(progress: Double)
    case processing(ProcessingStage)
    case ready
    case failed(RecordingFailure)

    public var isCapturingAudio: Bool {
        if case .recording = self {
            return true
        }
        return false
    }

    public var hasActiveSession: Bool {
        switch self {
        case .recording, .paused, .finalizing:
            return true
        default:
            return false
        }
    }
}

public enum RecordingEvent: Equatable, Sendable {
    case start(at: Date)
    case pause(at: Date)
    case resume(at: Date)
    case stop
    case finalized
    case uploadStarted
    case uploadProgress(Double)
    case uploadCompleted
    case processingChanged(ProcessingStage)
    case completed
    case failed(RecordingFailure)
    case retry
    case reset
}

public struct InvalidRecordingTransition: Error, Equatable, Sendable {
    public let stateDescription: String
    public let eventDescription: String

    public init(state: RecordingLifecycleState, event: RecordingEvent) {
        self.stateDescription = String(reflecting: state)
        self.eventDescription = String(reflecting: event)
    }
}

public struct RecordingStateMachine: Sendable {
    public private(set) var state: RecordingLifecycleState

    public init(state: RecordingLifecycleState = .idle) {
        self.state = state
    }

    public mutating func send(_ event: RecordingEvent) throws {
        if case let .failed(failure) = event, state != .idle {
            state = .failed(failure)
            return
        }

        switch (state, event) {
        case (.idle, let .start(startedAt)):
            state = .recording(startedAt: startedAt)

        case (let .recording(startedAt), let .pause(pausedAt)) where pausedAt >= startedAt:
            state = .paused(startedAt: startedAt, pausedAt: pausedAt)

        case (let .paused(startedAt, pausedAt), let .resume(resumedAt)) where resumedAt >= pausedAt:
            state = .recording(startedAt: startedAt)

        case (.recording, .stop), (.paused, .stop):
            state = .finalizing

        case (.finalizing, .finalized):
            state = .awaitingUpload

        case (.awaitingUpload, .uploadStarted):
            state = .uploading(progress: 0)

        case (.uploading, let .uploadProgress(progress)) where (0...1).contains(progress):
            state = .uploading(progress: progress)

        case (.uploading, .uploadCompleted):
            state = .processing(.queued)

        case (.processing, let .processingChanged(stage)):
            state = .processing(stage)

        case (.processing, .completed):
            state = .ready

        case (let .failed(failure), .retry) where failure.retryTarget == .upload:
            state = .awaitingUpload

        case (let .failed(failure), .retry) where failure.retryTarget == .processing:
            state = .processing(.queued)

        case (.ready, .reset), (.failed, .reset):
            state = .idle

        default:
            throw InvalidRecordingTransition(state: state, event: event)
        }
    }
}
