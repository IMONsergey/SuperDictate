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

public struct SuperDictateRecording: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var transcript: String
    public var summary: String?
    public var createdAt: Date
    public var durationSeconds: TimeInterval?
    public var people: [String]
    public var requiresAttention: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        transcript: String,
        summary: String? = nil,
        createdAt: Date = Date(),
        durationSeconds: TimeInterval? = nil,
        people: [String] = [],
        requiresAttention: Bool = false
    ) {
        self.id = id
        self.title = title
        self.transcript = transcript
        self.summary = summary
        self.createdAt = createdAt
        self.durationSeconds = durationSeconds
        self.people = people
        self.requiresAttention = requiresAttention
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
///
/// It deliberately contains product concepts, not ASR engines, checksums,
/// manifests, TCC details, model download state or updater internals. Those
/// concerns remain behind adapters and Settings/diagnostics surfaces.
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
        self.recordings = recordings.sorted { $0.createdAt > $1.createdAt }
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

    public var isCaptureActive: Bool {
        status == .recording
    }

    public var primaryCaptureCommand: SuperDictateCommand {
        isCaptureActive ? .stopRecording : .startRecording
    }
}

public enum SuperDictateCommand: Equatable, Sendable {
    case startRecording
    case stopRecording
    case openRecording(UUID)
    case copyTranscript(UUID)
    case toggleTask(UUID)
    case openSettings
    case retryAttentionItem(UUID)
}
