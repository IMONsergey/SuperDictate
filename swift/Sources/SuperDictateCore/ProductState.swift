import Foundation

/// The small set of destinations that may occupy the primary application sidebar.
/// Capture is intentionally not a destination: it is a global action.
public enum SuperDictateDestination: String, CaseIterable, Codable, Sendable, Identifiable {
    case today
    case library
    case tasks
    case ask
    public var id: String { rawValue }
}

public enum SuperDictateRuntimeStatus: String, Codable, Sendable {
    case idle
    case starting
    case recording
    case transcribing
    case ready
    case needsAttention = "needs_attention"
}

public enum SuperDictateRecordingSection: String, CaseIterable, Codable, Sendable, Identifiable {
    case summary
    case transcript
    case tasks
    public var id: String { rawValue }
}

/// Product-level origin/lifecycle of a Library recording.
public enum SuperDictateCaptureKind: String, Codable, CaseIterable, Sendable {
    case instantDictation = "instant_dictation"
    case memoryRecording = "memory_recording"
    case imported
}

public struct SuperDictateRecording: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var transcript: String
    public var summary: String?
    /// Optional for backward compatibility with Library archives written before
    /// capture kinds existed. A nil legacy value behaves as instant dictation.
    public var captureKind: SuperDictateCaptureKind?
    /// `nil` means the backing runtime does not know the capture timestamp.
    /// The UI must not substitute the current date and present it as source truth.
    public var createdAt: Date?
    public var durationSeconds: TimeInterval?
    public var people: [String]
    public var requiresAttention: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        transcript: String,
        summary: String? = nil,
        captureKind: SuperDictateCaptureKind? = .instantDictation,
        createdAt: Date? = nil,
        durationSeconds: TimeInterval? = nil,
        people: [String] = [],
        requiresAttention: Bool = false
    ) {
        self.id = id
        self.title = title
        self.transcript = transcript
        self.summary = summary
        self.captureKind = captureKind
        self.createdAt = createdAt
        self.durationSeconds = durationSeconds
        self.people = people
        self.requiresAttention = requiresAttention
    }

    public var effectiveCaptureKind: SuperDictateCaptureKind {
        captureKind ?? .instantDictation
    }
}

public struct SuperDictateTask: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var isCompleted: Bool
    public var sourceRecordingID: UUID?
    public var sourceExcerpt: String?
    public var dueAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        sourceRecordingID: UUID? = nil,
        sourceExcerpt: String? = nil,
        dueAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.sourceRecordingID = sourceRecordingID
        self.sourceExcerpt = sourceExcerpt
        self.dueAt = dueAt
    }
}

/// Platform-neutral state consumed by the macOS shell.
/// It deliberately contains product concepts, not ASR engines, checksums,
/// manifests, TCC details, model download state or updater internals.
public struct SuperDictateProductSnapshot: Codable, Equatable, Sendable {
    public var status: SuperDictateRuntimeStatus
    public var recordings: [SuperDictateRecording]
    public var tasks: [SuperDictateTask]
    public var activeRecordingStartedAt: Date?
    public var issueMessage: String?

    public init(
        status: SuperDictateRuntimeStatus = .idle,
        recordings: [SuperDictateRecording] = [],
        tasks: [SuperDictateTask] = [],
        activeRecordingStartedAt: Date? = nil,
        issueMessage: String? = nil
    ) {
        self.status = status
        self.recordings = Self.orderedRecordings(recordings)
        self.tasks = tasks
        self.activeRecordingStartedAt = activeRecordingStartedAt
        self.issueMessage = issueMessage
    }

    public var recentRecordings: [SuperDictateRecording] {
        Array(recordings.prefix(8))
    }

    public var actionableTasks: [SuperDictateTask] {
        tasks.filter { !$0.isCompleted }
    }

    public var attentionRecordings: [SuperDictateRecording] {
        recordings.filter(\.requiresAttention)
    }

    public var isCaptureActive: Bool { status == .recording }

    public var isPrimaryCaptureCommandEnabled: Bool {
        switch status {
        case .idle, .ready, .recording:
            return true
        case .starting, .transcribing, .needsAttention:
            return false
        }
    }

    public var primaryCaptureCommand: SuperDictateCommand {
        isCaptureActive ? .stopRecording : .startRecording
    }

    private static func orderedRecordings(_ source: [SuperDictateRecording]) -> [SuperDictateRecording] {
        source.enumerated()
            .sorted { lhs, rhs in
                switch (lhs.element.createdAt, rhs.element.createdAt) {
                case let (left?, right?):
                    if left != right { return left > right }
                    return lhs.offset < rhs.offset
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return lhs.offset < rhs.offset
                }
            }
            .map(\.element)
    }
}

public enum SuperDictateCommand: Equatable, Sendable {
    case startRecording
    case stopRecording
    case openRecording(UUID)
    case copyTranscript(UUID)
    case toggleTask(UUID)
    case openSettings
    case openSystemStatus
    case retryAttentionItem(UUID)
}
