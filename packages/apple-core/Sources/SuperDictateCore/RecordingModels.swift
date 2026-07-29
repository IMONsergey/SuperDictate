import Foundation

public enum RecordingMode: String, Codable, CaseIterable, Sendable {
    case quickThought = "quick_thought"
    case dictation
    case meeting
    case clientCorrections = "client_corrections"
    case interview
    case dailyMemory = "daily_memory"
    case custom
}

public enum SourcePlatform: String, Codable, CaseIterable, Sendable {
    case macOS = "macos"
    case iOS = "ios"
    case watchOS = "watchos"
    case android
    case wearOS = "wearos"
    case web
    case windows
}

public enum ProcessingStage: String, Codable, CaseIterable, Sendable {
    case queued
    case validatingSource = "validating_source"
    case transcribing
    case structuring
    case summarizing
    case extractingActions = "extracting_actions"
    case awaitingReview = "awaiting_review"
}

public enum RecordingMarkerKind: String, Codable, CaseIterable, Sendable {
    case important
    case task
    case decision
    case question
}

public struct RecordingMarker: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let offsetMilliseconds: Int64
    public let kind: RecordingMarkerKind
    public let note: String?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        offsetMilliseconds: Int64,
        kind: RecordingMarkerKind,
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        precondition(offsetMilliseconds >= 0, "Marker offset must not be negative")

        self.id = id
        self.offsetMilliseconds = offsetMilliseconds
        self.kind = kind
        self.note = note
        self.createdAt = createdAt
    }
}

public struct RecordingDescriptor: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let clientRecordingID: UUID
    public let sourcePlatform: SourcePlatform
    public let mode: RecordingMode
    public let startedAt: Date
    public var endedAt: Date?
    public var durationMilliseconds: Int64?
    public var projectID: UUID?
    public var localeIdentifier: String

    public init(
        id: UUID = UUID(),
        clientRecordingID: UUID = UUID(),
        sourcePlatform: SourcePlatform,
        mode: RecordingMode,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        durationMilliseconds: Int64? = nil,
        projectID: UUID? = nil,
        localeIdentifier: String = Locale.current.identifier
    ) {
        if let durationMilliseconds {
            precondition(durationMilliseconds >= 0, "Recording duration must not be negative")
        }

        self.id = id
        self.clientRecordingID = clientRecordingID
        self.sourcePlatform = sourcePlatform
        self.mode = mode
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationMilliseconds = durationMilliseconds
        self.projectID = projectID
        self.localeIdentifier = localeIdentifier
    }
}

public enum RetryTarget: String, Codable, Sendable {
    case none
    case upload
    case processing
}

public struct RecordingFailure: Error, Codable, Equatable, Sendable {
    public let code: String
    public let message: String
    public let retryTarget: RetryTarget

    public init(code: String, message: String, retryTarget: RetryTarget) {
        self.code = code
        self.message = message
        self.retryTarget = retryTarget
    }
}
