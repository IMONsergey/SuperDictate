import Foundation

public struct SuperDictateMemoryQuery: Codable, Equatable, Sendable {
    public var text: String
    /// Empty means all recordings currently present in the local index.
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
    public let id: UUID
    public let recordingID: UUID
    public let transcriptRevisionID: UUID
    public let segmentID: UUID
    public let startOffsetMilliseconds: Int64
    public let endOffsetMilliseconds: Int64
    public let speakerID: String?
    public let excerpt: String
    public let score: Double
    public let transcriptCreatedAt: Date

    public init(
        id: UUID = UUID(),
        recordingID: UUID,
        transcriptRevisionID: UUID,
        segmentID: UUID,
        startOffsetMilliseconds: Int64,
        endOffsetMilliseconds: Int64,
        speakerID: String?,
        excerpt: String,
        score: Double,
        transcriptCreatedAt: Date
    ) {
        self.id = id
        self.recordingID = recordingID
        self.transcriptRevisionID = transcriptRevisionID
        self.segmentID = segmentID
        self.startOffsetMilliseconds = max(0, startOffsetMilliseconds)
        self.endOffsetMilliseconds = max(self.startOffsetMilliseconds, endOffsetMilliseconds)
        self.speakerID = speakerID
        self.excerpt = excerpt
        self.score = max(0, score.isFinite ? score : 0)
        self.transcriptCreatedAt = transcriptCreatedAt
    }
}

/// Small, dependency-free local full-text index used as the evidence layer for
/// Library search and Ask.
///
/// This is deliberately not branded as semantic search. It is a deterministic
/// lexical ranker that can run offline everywhere the shared core runs. A future
/// embeddings adapter can add candidates, but generated answers must still cite
/// exact transcript spans from this layer or an equivalent evidence provider.
public struct SuperDictateLocalMemoryIndex: Sendable {
    private let transcripts: [LocalTranscript]

    public init(transcripts: [LocalTranscript]) {
        self.transcripts = transcripts
    }

    public func search(_ query: SuperDictateMemoryQuery) -> [SuperDictateMemorySearchHit] {
        let normalizedPhrase = Self.normalized(query.text)
        let queryTokens = Self.tokens(query.text)
        guard !normalizedPhrase.isEmpty, !queryTokens.isEmpty else { return [] }

        var candidates: [SuperDictateMemorySearchHit] = []

        for transcript in transcripts {
            guard query.recordingIDs.isEmpty
                    || query.recordingIDs.contains(transcript.recordingID) else {
                continue
            }

            for segment in transcript.segments {
                let score = Self.score(
                    candidateText: segment.text,
                    normalizedQueryPhrase: normalizedPhrase,
                    queryTokens: queryTokens
                )
                guard score > 0 else { continue }

                candidates.append(
                    SuperDictateMemorySearchHit(
                        recordingID: transcript.recordingID,
                        transcriptRevisionID: transcript.revisionID,
                        segmentID: segment.id,
                        startOffsetMilliseconds: segment.startOffsetMilliseconds,
                        endOffsetMilliseconds: segment.endOffsetMilliseconds,
                        speakerID: segment.speakerID,
                        excerpt: segment.text,
                        score: score,
                        transcriptCreatedAt: transcript.createdAt
                    )
                )
            }
        }

        return Array(
            candidates.sorted(by: Self.isHigherRanked).prefix(query.maximumResults)
        )
    }

    private static func score(
        candidateText: String,
        normalizedQueryPhrase: String,
        queryTokens: [String]
    ) -> Double {
        let normalizedCandidate = normalized(candidateText)
        let candidateTokens = tokens(candidateText)
        guard !candidateTokens.isEmpty else { return 0 }

        let candidateCounts = Dictionary(
            candidateTokens.map { ($0, 1) },
            uniquingKeysWith: +
        )

        var matchedUnique = 0
        var matchedOccurrences = 0
        for token in Set(queryTokens) {
            if let count = candidateCounts[token] {
                matchedUnique += 1
                matchedOccurrences += count
            }
        }
        guard matchedUnique > 0 else { return 0 }

        var score = Double(matchedUnique * 4 + min(matchedOccurrences, 8))
        if normalizedCandidate.contains(normalizedQueryPhrase) {
            score += 12
        }
        if matchedUnique == Set(queryTokens).count {
            score += 6
        }

        // Prefer focused evidence over giant segments when relevance is tied.
        let lengthPenalty = min(2.0, Double(max(0, candidateTokens.count - 40)) / 80.0)
        return max(0.001, score - lengthPenalty)
    }

    private static func isHigherRanked(
        _ lhs: SuperDictateMemorySearchHit,
        _ rhs: SuperDictateMemorySearchHit
    ) -> Bool {
        if lhs.score != rhs.score { return lhs.score > rhs.score }
        if lhs.transcriptCreatedAt != rhs.transcriptCreatedAt {
            return lhs.transcriptCreatedAt > rhs.transcriptCreatedAt
        }
        if lhs.recordingID != rhs.recordingID {
            return lhs.recordingID.uuidString < rhs.recordingID.uuidString
        }
        if lhs.startOffsetMilliseconds != rhs.startOffsetMilliseconds {
            return lhs.startOffsetMilliseconds < rhs.startOffsetMilliseconds
        }
        return lhs.segmentID.uuidString < rhs.segmentID.uuidString
    }

    private static func tokens(_ text: String) -> [String] {
        normalized(text)
            .split(whereSeparator: { character in
                !character.isLetter && !character.isNumber
            })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static func normalized(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
