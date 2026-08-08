import Foundation

public enum SuperDictateLibraryItemState: String, Codable, CaseIterable, Hashable, Sendable {
    case recording
    case processing
    case ready
    case needsReview = "needs_review"
    case needsAttention = "needs_attention"
    case failed
}

/// Stable, UI-facing projection of one recording.
///
/// The library intentionally does not expose storage paths, chunk checksums,
/// model implementation details, or recovery journals. Those remain behind
/// contextual technical detail surfaces.
public struct SuperDictateLibraryItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var createdAt: Date
    public var durationMilliseconds: Int64
    public var previewText: String?
    public var people: [String]
    public var tags: [String]
    public var state: SuperDictateLibraryItemState
    public var taskCount: Int
    public var requiresReviewCount: Int
    public var hasTranscript: Bool
    public var hasSummary: Bool

    public init(
        id: UUID,
        title: String,
        createdAt: Date,
        durationMilliseconds: Int64 = 0,
        previewText: String? = nil,
        people: [String] = [],
        tags: [String] = [],
        state: SuperDictateLibraryItemState = .ready,
        taskCount: Int = 0,
        requiresReviewCount: Int = 0,
        hasTranscript: Bool = false,
        hasSummary: Bool = false
    ) {
        self.id = id
        self.title = Self.normalizedTitle(title)
        self.createdAt = createdAt
        self.durationMilliseconds = max(0, durationMilliseconds)
        self.previewText = Self.normalizedOptionalText(previewText)
        self.people = Self.normalizedLabels(people)
        self.tags = Self.normalizedLabels(tags)
        self.state = state
        self.taskCount = max(0, taskCount)
        self.requiresReviewCount = max(0, requiresReviewCount)
        self.hasTranscript = hasTranscript
        self.hasSummary = hasSummary
    }

    public static func projecting(
        _ state: SuperDictateWorkbenchState,
        title: String = "Untitled recording"
    ) -> SuperDictateLibraryItem? {
        guard let id = state.recordingID else { return nil }

        let duration = state.transcript?.durationMilliseconds
            ?? state.manifest?.totalChunkDurationMilliseconds
            ?? 0
        let preview = state.transcript?.fullText
        let createdAt = state.transcript?.createdAt
            ?? state.summary?.generatedAt
            ?? state.updatedAt

        return SuperDictateLibraryItem(
            id: id,
            title: title,
            createdAt: createdAt,
            durationMilliseconds: duration,
            previewText: preview,
            state: Self.libraryState(from: state.status),
            taskCount: state.actionItems.count,
            requiresReviewCount: state.requiresReviewCount,
            hasTranscript: state.transcript != nil,
            hasSummary: state.summary != nil
        )
    }

    public var searchableText: String {
        ([title, previewText ?? ""] + people + tags)
            .joined(separator: "\n")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    private static func libraryState(
        from status: SuperDictateWorkbenchStatus
    ) -> SuperDictateLibraryItemState {
        switch status {
        case .idle, .ready:
            return .ready
        case .recording:
            return .recording
        case .processing:
            return .processing
        case .needsReview:
            return .needsReview
        case .needsAttention:
            return .needsAttention
        case .failed:
            return .failed
        }
    }

    private static func normalizedTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled recording" : trimmed
    }

    private static func normalizedOptionalText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedLabels(_ labels: [String]) -> [String] {
        var result: [String] = []
        var seen: Set<String> = []
        for label in labels {
            let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
            guard seen.insert(key).inserted else { continue }
            result.append(trimmed)
        }
        return result
    }
}

public enum SuperDictateLibrarySort: String, Codable, CaseIterable, Sendable {
    case newestFirst = "newest_first"
    case oldestFirst = "oldest_first"
    case longestFirst = "longest_first"
}

public struct SuperDictateLibrarySnapshot: Codable, Equatable, Sendable {
    public var items: [SuperDictateLibraryItem]

    public init(items: [SuperDictateLibraryItem] = []) {
        self.items = items
    }

    public func results(
        query: String = "",
        sort: SuperDictateLibrarySort = .newestFirst,
        states: Set<SuperDictateLibraryItemState> = []
    ) -> [SuperDictateLibraryItem] {
        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        let filtered = items.filter { item in
            let stateMatches = states.isEmpty || states.contains(item.state)
            let queryMatches = normalizedQuery.isEmpty || item.searchableText.contains(normalizedQuery)
            return stateMatches && queryMatches
        }

        return filtered.sorted { lhs, rhs in
            switch sort {
            case .newestFirst:
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            case .oldestFirst:
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            case .longestFirst:
                if lhs.durationMilliseconds != rhs.durationMilliseconds {
                    return lhs.durationMilliseconds > rhs.durationMilliseconds
                }
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    public var needsAttention: [SuperDictateLibraryItem] {
        results(states: [.needsReview, .needsAttention, .failed])
    }
}
