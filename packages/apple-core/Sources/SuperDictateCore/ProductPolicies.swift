import Foundation

public enum DataSensitivity: String, Codable, CaseIterable, Sendable {
    case standard
    case confidential
    case restricted
    case privateContent = "private"
}

public enum ConsentRequirement: String, Codable, CaseIterable, Sendable {
    case soloNote = "solo_note"
    case remindToInformParticipants = "remind_to_inform_participants"
    case confirmParticipantsInformed = "confirm_participants_informed"
    case prohibited
}

public enum CloudProcessingPolicy: String, Codable, CaseIterable, Sendable {
    case allowed
    case userChoice = "user_choice"
    case prohibited
}

public enum MemoryScope: String, Codable, CaseIterable, Sendable {
    case disabled
    case recording
    case project
    case workspace
    case personal
}

public enum RetentionPolicy: Codable, Equatable, Sendable {
    case deleteAfterProcessing
    case fixedDays(Int)
    case keepUntilDeleted
    case localOnly

    public var fixedDayCount: Int? {
        guard case let .fixedDays(days) = self else {
            return nil
        }

        return max(1, days)
    }

    public var permitsServerStorage: Bool {
        if case .localOnly = self {
            return false
        }

        return true
    }
}

public enum ProcessingArtifact: String, Codable, CaseIterable, Hashable, Sendable {
    case verbatimTranscript = "verbatim_transcript"
    case cleanedTranscript = "cleaned_transcript"
    case shortSummary = "short_summary"
    case detailedSummary = "detailed_summary"
    case topicChapters = "topic_chapters"
    case decisions
    case actionItems = "action_items"
    case commitments
    case openQuestions = "open_questions"
    case risks
    case clientCorrections = "client_corrections"
    case keyQuotes = "key_quotes"
    case followUpDraft = "follow_up_draft"
    case projectBriefUpdate = "project_brief_update"
    case memoryCandidates = "memory_candidates"
}

public struct RecordingProductPolicy: Codable, Equatable, Sendable {
    public var sensitivity: DataSensitivity
    public var consentRequirement: ConsentRequirement
    public var sourceAudioRetention: RetentionPolicy
    public var transcriptRetention: RetentionPolicy
    public var cloudProcessing: CloudProcessingPolicy
    public var memoryScope: MemoryScope
    public var requestedArtifacts: Set<ProcessingArtifact>
    public var requiresInsightReview: Bool

    public init(
        sensitivity: DataSensitivity,
        consentRequirement: ConsentRequirement,
        sourceAudioRetention: RetentionPolicy,
        transcriptRetention: RetentionPolicy,
        cloudProcessing: CloudProcessingPolicy,
        memoryScope: MemoryScope,
        requestedArtifacts: Set<ProcessingArtifact>,
        requiresInsightReview: Bool
    ) {
        self.sensitivity = sensitivity
        self.consentRequirement = consentRequirement
        self.sourceAudioRetention = sourceAudioRetention
        self.transcriptRetention = transcriptRetention
        self.cloudProcessing = cloudProcessing
        self.memoryScope = memoryScope
        self.requestedArtifacts = requestedArtifacts
        self.requiresInsightReview = requiresInsightReview
    }

    public var canUploadSourceAudio: Bool {
        sourceAudioRetention.permitsServerStorage && cloudProcessing != .prohibited
    }

    public var createsPersistentMemory: Bool {
        memoryScope != .disabled && requestedArtifacts.contains(.memoryCandidates)
    }
}

public extension RecordingMode {
    var defaultProductPolicy: RecordingProductPolicy {
        switch self {
        case .quickThought:
            return RecordingProductPolicy(
                sensitivity: .standard,
                consentRequirement: .soloNote,
                sourceAudioRetention: .deleteAfterProcessing,
                transcriptRetention: .keepUntilDeleted,
                cloudProcessing: .userChoice,
                memoryScope: .personal,
                requestedArtifacts: [
                    .cleanedTranscript,
                    .shortSummary,
                    .actionItems,
                    .memoryCandidates,
                ],
                requiresInsightReview: true
            )

        case .dictation:
            return RecordingProductPolicy(
                sensitivity: .standard,
                consentRequirement: .soloNote,
                sourceAudioRetention: .deleteAfterProcessing,
                transcriptRetention: .fixedDays(30),
                cloudProcessing: .userChoice,
                memoryScope: .disabled,
                requestedArtifacts: [.cleanedTranscript],
                requiresInsightReview: false
            )

        case .meeting:
            return RecordingProductPolicy(
                sensitivity: .confidential,
                consentRequirement: .confirmParticipantsInformed,
                sourceAudioRetention: .fixedDays(30),
                transcriptRetention: .keepUntilDeleted,
                cloudProcessing: .userChoice,
                memoryScope: .project,
                requestedArtifacts: [
                    .verbatimTranscript,
                    .detailedSummary,
                    .topicChapters,
                    .decisions,
                    .actionItems,
                    .commitments,
                    .openQuestions,
                    .risks,
                    .followUpDraft,
                    .memoryCandidates,
                ],
                requiresInsightReview: true
            )

        case .clientCorrections:
            return RecordingProductPolicy(
                sensitivity: .confidential,
                consentRequirement: .confirmParticipantsInformed,
                sourceAudioRetention: .fixedDays(30),
                transcriptRetention: .keepUntilDeleted,
                cloudProcessing: .userChoice,
                memoryScope: .project,
                requestedArtifacts: [
                    .verbatimTranscript,
                    .clientCorrections,
                    .actionItems,
                    .openQuestions,
                    .followUpDraft,
                    .projectBriefUpdate,
                    .memoryCandidates,
                ],
                requiresInsightReview: true
            )

        case .interview:
            return RecordingProductPolicy(
                sensitivity: .confidential,
                consentRequirement: .confirmParticipantsInformed,
                sourceAudioRetention: .fixedDays(30),
                transcriptRetention: .keepUntilDeleted,
                cloudProcessing: .userChoice,
                memoryScope: .recording,
                requestedArtifacts: [
                    .verbatimTranscript,
                    .topicChapters,
                    .detailedSummary,
                    .keyQuotes,
                    .openQuestions,
                ],
                requiresInsightReview: true
            )

        case .dailyMemory:
            return RecordingProductPolicy(
                sensitivity: .privateContent,
                consentRequirement: .soloNote,
                sourceAudioRetention: .deleteAfterProcessing,
                transcriptRetention: .keepUntilDeleted,
                cloudProcessing: .userChoice,
                memoryScope: .personal,
                requestedArtifacts: [
                    .cleanedTranscript,
                    .shortSummary,
                    .actionItems,
                    .memoryCandidates,
                ],
                requiresInsightReview: true
            )

        case .custom:
            return RecordingProductPolicy(
                sensitivity: .standard,
                consentRequirement: .remindToInformParticipants,
                sourceAudioRetention: .fixedDays(7),
                transcriptRetention: .keepUntilDeleted,
                cloudProcessing: .userChoice,
                memoryScope: .disabled,
                requestedArtifacts: [.verbatimTranscript],
                requiresInsightReview: true
            )
        }
    }
}
