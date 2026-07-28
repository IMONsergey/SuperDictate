import Foundation

public enum DomainValidationError: Error, Equatable, Sendable {
    case emptyStatement
    case missingEvidence
    case negativeOffset
    case invalidTimeRange
}

public struct EvidenceSpan: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let recordingID: UUID
    public let transcriptRevisionID: UUID
    public let startOffsetMilliseconds: Int64
    public let endOffsetMilliseconds: Int64
    public let speakerID: String?
    public let excerpt: String

    public init(
        id: UUID = UUID(),
        recordingID: UUID,
        transcriptRevisionID: UUID,
        startOffsetMilliseconds: Int64,
        endOffsetMilliseconds: Int64,
        speakerID: String? = nil,
        excerpt: String
    ) throws {
        guard startOffsetMilliseconds >= 0, endOffsetMilliseconds >= 0 else {
            throw DomainValidationError.negativeOffset
        }

        guard endOffsetMilliseconds >= startOffsetMilliseconds else {
            throw DomainValidationError.invalidTimeRange
        }

        self.id = id
        self.recordingID = recordingID
        self.transcriptRevisionID = transcriptRevisionID
        self.startOffsetMilliseconds = startOffsetMilliseconds
        self.endOffsetMilliseconds = endOffsetMilliseconds
        self.speakerID = speakerID
        self.excerpt = excerpt
    }
}

public enum InsightKind: String, Codable, CaseIterable, Sendable {
    case decision
    case actionItem = "action_item"
    case commitment
    case openQuestion = "open_question"
    case risk
    case clientCorrection = "client_correction"
    case factCandidate = "fact_candidate"
    case notableMoment = "notable_moment"
}

public enum ConfidenceLevel: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high
    case userConfirmed = "user_confirmed"
}

public enum InsightReviewState: String, Codable, CaseIterable, Sendable {
    case candidate
    case approved
    case rejected
    case superseded
    case revoked
}

public struct ExtractedInsight: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let recordingID: UUID
    public let kind: InsightKind
    public var statement: String
    public var confidence: ConfidenceLevel
    public var reviewState: InsightReviewState
    public var evidence: [EvidenceSpan]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        recordingID: UUID,
        kind: InsightKind,
        statement: String,
        confidence: ConfidenceLevel,
        reviewState: InsightReviewState = .candidate,
        evidence: [EvidenceSpan],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) throws {
        guard !statement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainValidationError.emptyStatement
        }

        guard !evidence.isEmpty else {
            throw DomainValidationError.missingEvidence
        }

        self.id = id
        self.recordingID = recordingID
        self.kind = kind
        self.statement = statement
        self.confidence = confidence
        self.reviewState = reviewState
        self.evidence = evidence
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var isUserTrusted: Bool {
        confidence == .userConfirmed || reviewState == .approved
    }
}

public enum MemoryReviewState: String, Codable, CaseIterable, Sendable {
    case candidate
    case approved
    case rejected
    case active
    case contradicted
    case superseded
    case expired
    case revoked
}

public struct MemoryCandidate: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let sourceInsightID: UUID
    public var statement: String
    public var scope: MemoryScope
    public var sensitivity: DataSensitivity
    public var reviewState: MemoryReviewState
    public var validFrom: Date?
    public var validUntil: Date?
    public var supersedesMemoryID: UUID?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        sourceInsightID: UUID,
        statement: String,
        scope: MemoryScope,
        sensitivity: DataSensitivity,
        reviewState: MemoryReviewState = .candidate,
        validFrom: Date? = nil,
        validUntil: Date? = nil,
        supersedesMemoryID: UUID? = nil,
        createdAt: Date = Date()
    ) throws {
        guard !statement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainValidationError.emptyStatement
        }

        self.id = id
        self.sourceInsightID = sourceInsightID
        self.statement = statement
        self.scope = scope
        self.sensitivity = sensitivity
        self.reviewState = reviewState
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.supersedesMemoryID = supersedesMemoryID
        self.createdAt = createdAt
    }

    public func isValid(at date: Date) -> Bool {
        if let validFrom, date < validFrom {
            return false
        }

        if let validUntil, date > validUntil {
            return false
        }

        return ![.rejected, .expired, .revoked, .superseded].contains(reviewState)
    }
}

public enum ActionSynchronizationState: String, Codable, CaseIterable, Sendable {
    case local
    case awaitingApproval = "awaiting_approval"
    case synchronizing
    case synchronized
    case failedRecoverable = "failed_recoverable"
    case failedPermanent = "failed_permanent"
}

public struct ActionItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let sourceInsightID: UUID
    public var title: String
    public var details: String?
    public var explicitOwner: String?
    public var suggestedOwner: String?
    public var explicitDueDate: Date?
    public var suggestedDueDate: Date?
    public var synchronizationState: ActionSynchronizationState
    public var externalReference: String?

    public init(
        id: UUID = UUID(),
        sourceInsightID: UUID,
        title: String,
        details: String? = nil,
        explicitOwner: String? = nil,
        suggestedOwner: String? = nil,
        explicitDueDate: Date? = nil,
        suggestedDueDate: Date? = nil,
        synchronizationState: ActionSynchronizationState = .local,
        externalReference: String? = nil
    ) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainValidationError.emptyStatement
        }

        self.id = id
        self.sourceInsightID = sourceInsightID
        self.title = title
        self.details = details
        self.explicitOwner = explicitOwner
        self.suggestedOwner = suggestedOwner
        self.explicitDueDate = explicitDueDate
        self.suggestedDueDate = suggestedDueDate
        self.synchronizationState = synchronizationState
        self.externalReference = externalReference
    }

    public var requiresAssignmentReview: Bool {
        explicitOwner == nil && suggestedOwner != nil
    }

    public var requiresDueDateReview: Bool {
        explicitDueDate == nil && suggestedDueDate != nil
    }
}
