import Foundation

public enum SuperDictateMemoryAnswerStatus: String, Codable, CaseIterable, Sendable {
    case grounded
    case insufficientEvidence = "insufficient_evidence"
}

public enum SuperDictateMemoryAnswerValidationError: Error, Equatable, Sendable {
    case emptyAnswer
    case groundedAnswerWithoutCitations
    case citationWithoutExcerpt
}

public struct SuperDictateMemoryCitation: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let searchHitID: UUID
    public let recordingID: UUID
    public let startOffsetMilliseconds: Int64
    public let endOffsetMilliseconds: Int64
    public let excerpt: String

    public init(
        id: UUID = UUID(),
        searchHit: SuperDictateMemorySearchHit
    ) throws {
        let excerpt = searchHit.excerpt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !excerpt.isEmpty else {
            throw SuperDictateMemoryAnswerValidationError.citationWithoutExcerpt
        }

        self.id = id
        self.searchHitID = searchHit.id
        self.recordingID = searchHit.recordingID
        self.startOffsetMilliseconds = searchHit.startOffsetMilliseconds
        self.endOffsetMilliseconds = searchHit.endOffsetMilliseconds
        self.excerpt = excerpt
    }
}

/// Output contract for Ask SuperDictate.
///
/// A model can phrase an answer, but it cannot mark the answer as grounded
/// unless at least one exact local transcript citation is attached. This keeps
/// generated prose distinct from source memory and prevents a future LLM
/// adapter from silently returning uncited claims as trusted product state.
public struct SuperDictateMemoryAnswer: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let query: SuperDictateMemoryQuery
    public let text: String
    public let status: SuperDictateMemoryAnswerStatus
    public let citations: [SuperDictateMemoryCitation]
    public let generatedAt: Date
    public let modelID: String?

    public init(
        id: UUID = UUID(),
        query: SuperDictateMemoryQuery,
        text: String,
        status: SuperDictateMemoryAnswerStatus,
        citations: [SuperDictateMemoryCitation],
        generatedAt: Date = Date(),
        modelID: String? = nil
    ) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SuperDictateMemoryAnswerValidationError.emptyAnswer
        }
        if status == .grounded, citations.isEmpty {
            throw SuperDictateMemoryAnswerValidationError.groundedAnswerWithoutCitations
        }

        self.id = id
        self.query = query
        self.text = trimmed
        self.status = status
        self.citations = citations
        self.generatedAt = generatedAt
        self.modelID = modelID
    }

    public static func insufficientEvidence(
        for query: SuperDictateMemoryQuery,
        message: String = "I couldn't find enough source evidence in the selected recordings."
    ) throws -> SuperDictateMemoryAnswer {
        try SuperDictateMemoryAnswer(
            query: query,
            text: message,
            status: .insufficientEvidence,
            citations: []
        )
    }
}
