import Foundation

public enum SuperDictateIntelligenceCapability: String, Codable, CaseIterable, Sendable {
    case answer
    case summarize
    case extractTasks = "extract_tasks"
}

public struct SuperDictateIntelligenceProviderDescriptor: Codable, Equatable, Sendable {
    public var providerID: String
    public var modelID: String
    public var capabilities: Set<SuperDictateIntelligenceCapability>
    public var isLocal: Bool

    public init(
        providerID: String,
        modelID: String,
        capabilities: Set<SuperDictateIntelligenceCapability>,
        isLocal: Bool
    ) {
        self.providerID = providerID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.modelID = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.capabilities = capabilities
        self.isLocal = isLocal
    }
}

/// Exact source reference used by synthesized Summary/Tasks.
///
/// Generated text is allowed to be concise or reformulated, but grounded product
/// output always keeps links back to immutable evidence segments. This is the
/// same trust rule already enforced by evidence-first Ask.
public struct SuperDictateEvidenceCitation: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID { segmentID }
    public var recordingID: UUID
    public var segmentID: UUID
    public var excerpt: String
    public var speaker: String?
    public var startMilliseconds: Int64?
    public var endMilliseconds: Int64?

    public init(
        recordingID: UUID,
        segment: SuperDictateEvidenceSegment
    ) {
        self.recordingID = recordingID
        self.segmentID = segment.id
        self.excerpt = segment.text
        self.speaker = segment.speaker
        self.startMilliseconds = segment.startMilliseconds
        self.endMilliseconds = segment.endMilliseconds
    }

    public init(hit: SuperDictateMemorySearchHit) {
        self.recordingID = hit.recordingID
        self.segmentID = hit.segmentID
        self.excerpt = hit.excerpt
        self.speaker = hit.speaker
        self.startMilliseconds = hit.startMilliseconds
        self.endMilliseconds = hit.endMilliseconds
    }

    public var hasTimestamp: Bool {
        startMilliseconds != nil && endMilliseconds != nil
    }
}

public enum SuperDictateGroundedGenerationError: Error, Equatable, Sendable {
    case emptyText
    case missingEvidence
    case emptyResult
}

public struct SuperDictateGroundedSummarySection: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var text: String
    public var citations: [SuperDictateEvidenceCitation]

    public init(
        id: UUID = UUID(),
        title: String,
        text: String,
        citations: [SuperDictateEvidenceCitation]
    ) throws {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !text.isEmpty else {
            throw SuperDictateGroundedGenerationError.emptyText
        }
        guard !citations.isEmpty else {
            throw SuperDictateGroundedGenerationError.missingEvidence
        }
        self.id = id
        self.title = title
        self.text = text
        self.citations = citations
    }
}

public struct SuperDictateGroundedSummary: Codable, Equatable, Sendable {
    public var sections: [SuperDictateGroundedSummarySection]
    public var modelID: String

    public init(
        sections: [SuperDictateGroundedSummarySection],
        modelID: String
    ) throws {
        guard !sections.isEmpty else {
            throw SuperDictateGroundedGenerationError.emptyResult
        }
        self.sections = sections
        self.modelID = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct SuperDictateGroundedTaskProposal: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var citations: [SuperDictateEvidenceCitation]
    public var dueAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        citations: [SuperDictateEvidenceCitation],
        dueAt: Date? = nil
    ) throws {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            throw SuperDictateGroundedGenerationError.emptyText
        }
        guard !citations.isEmpty else {
            throw SuperDictateGroundedGenerationError.missingEvidence
        }
        self.id = id
        self.title = title
        self.citations = citations
        self.dueAt = dueAt
    }
}

public struct SuperDictateGroundedTaskExtraction: Codable, Equatable, Sendable {
    public var tasks: [SuperDictateGroundedTaskProposal]
    public var modelID: String

    public init(tasks: [SuperDictateGroundedTaskProposal], modelID: String) {
        self.tasks = tasks
        self.modelID = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Backend-neutral synthesis boundary.
///
/// Concrete providers may use llama.cpp, MLX, a future Apple Foundation Models
/// adapter or an explicitly enabled cloud model. Primary product UI and durable
/// Library types do not depend on those implementations.
public protocol SuperDictateIntelligenceProvider: Sendable {
    var descriptor: SuperDictateIntelligenceProviderDescriptor { get }

    func answer(
        query: SuperDictateMemoryQuery,
        evidence: [SuperDictateMemorySearchHit]
    ) async throws -> SuperDictateMemoryAnswer

    func summarize(
        document: SuperDictateMemoryDocument
    ) async throws -> SuperDictateGroundedSummary

    func extractTasks(
        document: SuperDictateMemoryDocument
    ) async throws -> SuperDictateGroundedTaskExtraction
}
