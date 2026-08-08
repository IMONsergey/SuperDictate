import SwiftUI
import SuperDictateCore

/// Honest local Ask surface that works before a generative model is connected.
///
/// The first useful version of Ask is retrieval, not a fake chatbot. It searches
/// local transcript evidence, shows exact source excerpts and timestamps, and
/// establishes the interaction contract a future grounded answer model must use.
public struct SuperDictateLocalAskView: View {
    private let transcripts: [LocalTranscript]
    private let scopeRecordingIDs: Set<UUID>
    private let onOpenEvidence: (SuperDictateMemorySearchHit) -> Void

    @State private var query = ""
    @State private var submittedQuery = ""
    @State private var hits: [SuperDictateMemorySearchHit] = []

    public init(
        transcripts: [LocalTranscript],
        scopeRecordingIDs: Set<UUID> = [],
        onOpenEvidence: @escaping (SuperDictateMemorySearchHit) -> Void = { _ in }
    ) {
        self.transcripts = transcripts
        self.scopeRecordingIDs = scopeRecordingIDs
        self.onOpenEvidence = onOpenEvidence
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.section) {
                    header
                    results
                }
                .padding(SuperDictateDesign.Spacing.contentGutter)
                .superDictateReadableDocument()
            }

            Divider()
            composer
        }
        .background(SuperDictateDesign.ColorRole.canvas)
        .navigationTitle("Ask")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.inline) {
            Text("Ask your memory")
                .font(SuperDictateDesign.TypeStyle.title)
            Text(scopeDescription)
                .font(SuperDictateDesign.TypeStyle.body)
                .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
        }
    }

    @ViewBuilder
    private var results: some View {
        if transcripts.isEmpty {
            ContentUnavailableView(
                "Nothing to search yet",
                systemImage: "text.magnifyingglass",
                description: Text("Record or import a conversation first. Ask searches local transcript evidence and never invents missing source material.")
            )
            .frame(maxWidth: .infinity, minHeight: 260)
        } else if submittedQuery.isEmpty {
            VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.component) {
                Text("Try asking about a decision, promise, name, deadline or topic.")
                    .font(SuperDictateDesign.TypeStyle.body)
                    .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)

                AskSuggestion(title: "What did we decide?", action: { submit("What did we decide?") })
                AskSuggestion(title: "What needs to happen next?", action: { submit("What needs to happen next?") })
                AskSuggestion(title: "Find mentions of a client or project", action: {
                    query = ""
                })
            }
        } else if hits.isEmpty {
            ContentUnavailableView(
                "No source evidence found",
                systemImage: "magnifyingglass",
                description: Text("Try different words or broaden the recording scope. SuperDictate will not fabricate an answer when the local transcript does not support one.")
            )
            .frame(maxWidth: .infinity, minHeight: 240)
        } else {
            LazyVStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Source matches")
                        .font(SuperDictateDesign.TypeStyle.heading)
                    Spacer()
                    Text("\(hits.count)")
                        .font(SuperDictateDesign.TypeStyle.captionMedium)
                        .foregroundStyle(SuperDictateDesign.ColorRole.textTertiary)
                }
                .padding(.bottom, SuperDictateDesign.Spacing.inline)

                ForEach(Array(hits.enumerated()), id: \.element.id) { index, hit in
                    EvidenceResultRow(hit: hit) {
                        onOpenEvidence(hit)
                    }
                    if index < hits.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: SuperDictateDesign.Spacing.inline) {
            TextField(
                "Ask about your recordings",
                text: $query,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(SuperDictateDesign.TypeStyle.body)
            .lineLimit(1...5)
            .onSubmit { submit(query) }

            Button {
                submit(query)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(
                query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? SuperDictateDesign.ColorRole.textTertiary
                    : SuperDictateDesign.ColorRole.actionPrimary
            )
            .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Search memory")
        }
        .padding(.horizontal, SuperDictateDesign.Spacing.contentGutter)
        .padding(.vertical, SuperDictateDesign.Spacing.compact)
        .frame(maxWidth: SuperDictateDesign.Layout.documentMaxReadableWidth + (SuperDictateDesign.Spacing.contentGutter * 2))
        .frame(maxWidth: .infinity)
        .background(SuperDictateDesign.ColorRole.canvas)
    }

    private var scopeDescription: String {
        if transcripts.isEmpty {
            return "Local transcript search"
        }
        if scopeRecordingIDs.count == 1 {
            return "Searching this recording. Every result links to an exact source moment."
        }
        if !scopeRecordingIDs.isEmpty {
            return "Searching \(scopeRecordingIDs.count) selected recordings. Every result links to source evidence."
        }
        return "Searching \(transcripts.count) local transcript\(transcripts.count == 1 ? "" : "s"). Every result links to an exact source moment."
    }

    private func submit(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        query = trimmed
        submittedQuery = trimmed
        hits = SuperDictateLocalMemoryIndex(transcripts: transcripts).search(
            SuperDictateMemoryQuery(
                text: trimmed,
                recordingIDs: scopeRecordingIDs,
                maximumResults: 12
            )
        )
    }
}

private struct AskSuggestion: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SuperDictateDesign.Spacing.inline) {
                Text(title)
                    .font(SuperDictateDesign.TypeStyle.interface)
                    .foregroundStyle(SuperDictateDesign.ColorRole.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(SuperDictateDesign.ColorRole.textTertiary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, SuperDictateDesign.Spacing.inline)
        }
        .buttonStyle(.plain)
    }
}

private struct EvidenceResultRow: View {
    let hit: SuperDictateMemorySearchHit
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: SuperDictateDesign.Spacing.component) {
                Text(formatMemoryTimestamp(hit.startOffsetMilliseconds))
                    .font(SuperDictateDesign.TypeStyle.timestamp)
                    .foregroundStyle(SuperDictateDesign.ColorRole.textTertiary)
                    .frame(width: 52, alignment: .leading)

                VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.micro) {
                    Text(hit.excerpt)
                        .font(SuperDictateDesign.TypeStyle.body)
                        .foregroundStyle(SuperDictateDesign.ColorRole.textPrimary)
                        .multilineTextAlignment(.leading)
                        .textSelection(.enabled)

                    HStack(spacing: SuperDictateDesign.Spacing.inline) {
                        Text("Source \(hit.recordingID.uuidString.prefix(8))")
                        if let speakerID = hit.speakerID, !speakerID.isEmpty {
                            Text("·")
                            Text(speakerID)
                        }
                    }
                    .font(SuperDictateDesign.TypeStyle.caption)
                    .foregroundStyle(SuperDictateDesign.ColorRole.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(SuperDictateDesign.ColorRole.textTertiary)
                    .padding(.top, 3)
            }
            .contentShape(Rectangle())
            .padding(.vertical, SuperDictateDesign.Spacing.compact)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open source at \(formatMemoryTimestamp(hit.startOffsetMilliseconds))")
    }
}

private func formatMemoryTimestamp(_ milliseconds: Int64) -> String {
    let totalSeconds = max(0, milliseconds / 1_000)
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    let seconds = totalSeconds % 60
    if hours > 0 {
        return String(format: "%lld:%02lld:%02lld", hours, minutes, seconds)
    }
    return String(format: "%02lld:%02lld", minutes, seconds)
}
