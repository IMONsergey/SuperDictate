import Foundation

public struct SuperDictateEvidenceSegment: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var text: String
    public var speaker: String?
    public var startMilliseconds: Int64?
    public var endMilliseconds: Int64?

    public init(
        id: UUID = UUID(),
        text: String,
        speaker: String? = nil,
        startMilliseconds: Int64? = nil,
        endMilliseconds: Int64? = nil
    ) {
        self.id = id
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.speaker = Self.normalizedOptional(speaker)

        if let startMilliseconds,
           let endMilliseconds,
           startMilliseconds >= 0,
           endMilliseconds >= startMilliseconds {
            self.startMilliseconds = startMilliseconds
            self.endMilliseconds = endMilliseconds
        } else {
            self.startMilliseconds = nil
            self.endMilliseconds = nil
        }
    }

    public var hasTimestamp: Bool {
        startMilliseconds != nil && endMilliseconds != nil
    }

    private static func normalizedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Searchable evidence projection of a recording.
///
/// The product recording remains intentionally small. Search/Ask can evolve to
/// richer timed segments without forcing ASR details into every primary UI
/// model or breaking legacy plain-text history.
public struct SuperDictateMemoryDocument: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID { recordingID }
    public var recordingID: UUID
    public var title: String
    /// `nil` is preserved for legacy/runtime sources that do not know the date.
    public var createdAt: Date?
    public var people: [String]
    public var tags: [String]
    public var segments: [SuperDictateEvidenceSegment]

    public init(
        recordingID: UUID,
        title: String,
        createdAt: Date? = nil,
        people: [String] = [],
        tags: [String] = [],
        segments: [SuperDictateEvidenceSegment]
    ) {
        self.recordingID = recordingID
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = trimmedTitle.isEmpty ? "Untitled recording" : trimmedTitle
        self.createdAt = createdAt
        self.people = Self.normalizedLabels(people)
        self.tags = Self.normalizedLabels(tags)
        self.segments = segments.filter { !$0.text.isEmpty }
    }

    public init(recording: SuperDictateRecording) {
        let fallbackSegment = SuperDictateEvidenceSegment(text: recording.transcript)
        self.init(
            recordingID: recording.id,
            title: recording.title,
            createdAt: recording.createdAt,
            people: recording.people,
            segments: fallbackSegment.text.isEmpty ? [] : [fallbackSegment]
        )
    }

    public var fullText: String {
        segments.map(\.text).joined(separator: "\n")
    }

    public var searchableText: String {
        ([title, fullText] + people + tags)
            .joined(separator: "\n")
    }

    private static func normalizedLabels(_ values: [String]) -> [String] {
        var result: [String] = []
        var seen: Set<String> = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = normalized(trimmed)
            guard seen.insert(key).inserted else { continue }
            result.append(trimmed)
        }
        return result
    }
}

public struct SuperDictateMemoryQuery: Codable, Equatable, Sendable {
    public var text: String
    /// Empty means every local document in the index.
    public var recordingIDs: Set<UUID>
    public var maximumResults: Int

    public init(
        text: String,
        recordingIDs: Set<UUID> = [],
        maximumResults: Int = 12
    ) {
        self.text = text
        self.recordingIDs = recordingIDs
        self.maximumResults = min(50, max(1, maximumResults))
    }
}

public struct SuperDictateMemorySearchHit: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var recordingID: UUID
    public var documentCreatedAt: Date?
    public var segmentID: UUID
    public var excerpt: String
    public var speaker: String?
    public var startMilliseconds: Int64?
    public var endMilliseconds: Int64?
    public var score: Double

    public init(
        id: UUID = UUID(),
        document: SuperDictateMemoryDocument,
        segment: SuperDictateEvidenceSegment,
        score: Double
    ) {
        self.id = id
        self.recordingID = document.recordingID
        self.documentCreatedAt = document.createdAt
        self.segmentID = segment.id
        self.excerpt = segment.text
        self.speaker = segment.speaker
        self.startMilliseconds = segment.startMilliseconds
        self.endMilliseconds = segment.endMilliseconds
        self.score = max(0, score.isFinite ? score : 0)
    }

    public var hasTimestamp: Bool {
        startMilliseconds != nil && endMilliseconds != nil
    }
}

/// Dependency-free local evidence retrieval.
///
/// This intentionally describes itself as lexical search, not semantic search.
/// A later embedding adapter may contribute candidates, but source citations
/// must still resolve to exact local evidence segments.
public struct SuperDictateLocalMemoryIndex: Sendable {
    public var documents: [SuperDictateMemoryDocument]

    public init(documents: [SuperDictateMemoryDocument]) {
        var latestByID: [UUID: SuperDictateMemoryDocument] = [:]
        for document in documents {
            if let existing = latestByID[document.recordingID],
               !Self.shouldReplace(existing: existing, with: document) {
                continue
            }
            latestByID[document.recordingID] = document
        }
        self.documents = latestByID.values.sorted { lhs, rhs in
            if Self.dateRanksBefore(lhs.createdAt, rhs.createdAt) { return true }
            if Self.dateRanksBefore(rhs.createdAt, lhs.createdAt) { return false }
            return lhs.recordingID.uuidString < rhs.recordingID.uuidString
        }
    }

    public func search(_ query: SuperDictateMemoryQuery) -> [SuperDictateMemorySearchHit] {
        let phrase = normalized(query.text)
        let queryTokens = tokens(query.text)
        guard !phrase.isEmpty, !queryTokens.isEmpty else { return [] }

        var hits: [SuperDictateMemorySearchHit] = []
        for document in documents {
            guard query.recordingIDs.isEmpty || query.recordingIDs.contains(document.recordingID) else {
                continue
            }

            for segment in document.segments {
                let score = Self.score(
                    candidate: segment.text,
                    queryPhrase: phrase,
                    queryTokens: queryTokens
                )
                guard score > 0 else { continue }
                hits.append(
                    SuperDictateMemorySearchHit(
                        document: document,
                        segment: segment,
                        score: score
                    )
                )
            }
        }

        return Array(hits.sorted(by: Self.ranksBefore).prefix(query.maximumResults))
    }

    public func matchingDocuments(
        text: String,
        maximumResults: Int = 100
    ) -> [SuperDictateMemoryDocument] {
        let phrase = normalized(text)
        let queryTokens = tokens(text)
        guard !phrase.isEmpty, !queryTokens.isEmpty else {
            return Array(documents.prefix(min(100, max(1, maximumResults))))
        }

        return documents
            .compactMap { document -> (SuperDictateMemoryDocument, Double)? in
                let score = Self.score(
                    candidate: document.searchableText,
                    queryPhrase: phrase,
                    queryTokens: queryTokens
                )
                return score > 0 ? (document, score) : nil
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                if Self.dateRanksBefore(lhs.0.createdAt, rhs.0.createdAt) { return true }
                if Self.dateRanksBefore(rhs.0.createdAt, lhs.0.createdAt) { return false }
                return lhs.0.recordingID.uuidString < rhs.0.recordingID.uuidString
            }
            .prefix(min(100, max(1, maximumResults)))
            .map(\.0)
    }

    private static func score(
        candidate: String,
        queryPhrase: String,
        queryTokens: [String]
    ) -> Double {
        let candidateNormalized = normalized(candidate)
        let candidateTokens = tokens(candidate)
        guard !candidateTokens.isEmpty else { return 0 }

        let counts = Dictionary(candidateTokens.map { ($0, 1) }, uniquingKeysWith: +)
        let uniqueQueryTokens = Set(queryTokens)
        var matchedUnique = 0
        var matchedOccurrences = 0

        for token in uniqueQueryTokens {
            if let count = counts[token] {
                matchedUnique += 1
                matchedOccurrences += count
            }
        }
        guard matchedUnique > 0 else { return 0 }

        var score = Double(matchedUnique * 4 + min(matchedOccurrences, 8))
        if candidateNormalized.contains(queryPhrase) { score += 12 }
        if matchedUnique == uniqueQueryTokens.count { score += 6 }

        let lengthPenalty = min(
            2.0,
            Double(max(0, candidateTokens.count - 40)) / 80.0
        )
        return max(0.001, score - lengthPenalty)
    }

    private static func ranksBefore(
        _ lhs: SuperDictateMemorySearchHit,
        _ rhs: SuperDictateMemorySearchHit
    ) -> Bool {
        if lhs.score != rhs.score { return lhs.score > rhs.score }
        if dateRanksBefore(lhs.documentCreatedAt, rhs.documentCreatedAt) { return true }
        if dateRanksBefore(rhs.documentCreatedAt, lhs.documentCreatedAt) { return false }
        if lhs.recordingID != rhs.recordingID {
            return lhs.recordingID.uuidString < rhs.recordingID.uuidString
        }
        let leftStart = lhs.startMilliseconds ?? Int64.max
        let rightStart = rhs.startMilliseconds ?? Int64.max
        if leftStart != rightStart { return leftStart < rightStart }
        return lhs.segmentID.uuidString < rhs.segmentID.uuidString
    }

    private static func shouldReplace(
        existing: SuperDictateMemoryDocument,
        with candidate: SuperDictateMemoryDocument
    ) -> Bool {
        switch (existing.createdAt, candidate.createdAt) {
        case let (old?, new?):
            return new >= old
        case (nil, _?):
            return true
        case (_?, nil):
            return false
        case (nil, nil):
            // With no source timestamps, the last projection supplied by the
            // runtime wins. We do not fabricate chronology.
            return true
        }
    }

    private static func dateRanksBefore(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case let (left?, right?):
            return left > right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return false
        }
    }
}

public enum SuperDictateMemoryAnswerStatus: String, Codable, Sendable {
    case grounded
    case insufficientEvidence = "insufficient_evidence"
}

public enum SuperDictateMemoryAnswerError: Error, Equatable, Sendable {
    case emptyAnswer
    case groundedWithoutEvidence
}

public struct SuperDictateMemoryAnswer: Codable, Equatable, Sendable {
    public var text: String
    public var status: SuperDictateMemoryAnswerStatus
    public var citations: [SuperDictateMemorySearchHit]
    public var modelID: String?

    public init(
        text: String,
        status: SuperDictateMemoryAnswerStatus,
        citations: [SuperDictateMemorySearchHit],
        modelID: String? = nil
    ) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SuperDictateMemoryAnswerError.emptyAnswer }
        if status == .grounded, citations.isEmpty {
            throw SuperDictateMemoryAnswerError.groundedWithoutEvidence
        }
        self.text = trimmed
        self.status = status
        self.citations = citations
        self.modelID = modelID
    }
}

private func normalized(_ text: String) -> String {
    text
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        .lowercased()
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func tokens(_ text: String) -> [String] {
    normalized(text)
        .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        .map(String.init)
        .filter { !$0.isEmpty }
}
