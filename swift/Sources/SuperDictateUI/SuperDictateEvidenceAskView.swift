import SwiftUI
import SuperDictateCore

/// Native Ask surface backed by exact local transcript evidence.
///
/// This intentionally ships retrieval before generative synthesis. It works
/// offline and establishes the contract that every future generated answer must
/// be able to jump back to source evidence.
public struct SuperDictateEvidenceAskView: View {
    private let documents: [SuperDictateMemoryDocument]
    private let scopeRecordingIDs: Set<UUID>
    private let language: SuperDictateInterfaceLanguage
    private let onOpenEvidence: (SuperDictateMemorySearchHit) -> Void

    @State private var query = ""
    @State private var submittedQuery = ""
    @State private var hits: [SuperDictateMemorySearchHit] = []

    public init(
        documents: [SuperDictateMemoryDocument],
        scopeRecordingIDs: Set<UUID> = [],
        language: SuperDictateInterfaceLanguage = .english,
        onOpenEvidence: @escaping (SuperDictateMemorySearchHit) -> Void = { _ in }
    ) {
        self.documents = documents
        self.scopeRecordingIDs = scopeRecordingIDs
        self.language = language
        self.onOpenEvidence = onOpenEvidence
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.section) {
                    header
                    resultContent
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

    private var isRussian: Bool { language == .russian }

    private func t(_ russian: String, _ english: String) -> String {
        isRussian ? russian : english
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.inline) {
            Text(t("Спросите свою память", "Ask your memory"))
                .font(SuperDictateDesign.TypeStyle.display)
            Text(scopeDescription)
                .font(SuperDictateDesign.TypeStyle.body)
                .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        if scopedDocuments.isEmpty {
            ContentUnavailableView(
                t("Пока нечего искать", "Nothing to search yet"),
                systemImage: "text.magnifyingglass",
                description: Text(t(
                    "Сначала запишите или добавьте разговор. Ask ищет только в локальном исходном тексте и не придумывает отсутствующие факты.",
                    "Record or import a conversation first. Ask searches local source text and does not invent missing memory."
                ))
            )
            .frame(maxWidth: .infinity, minHeight: 260)
        } else if submittedQuery.isEmpty {
            VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.compact) {
                Text(t(
                    "Ищите решения, обещания, имена, сроки или темы.",
                    "Search decisions, promises, names, deadlines or topics."
                ))
                .font(SuperDictateDesign.TypeStyle.body)
                .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)

                querySuggestion(t("Что мы решили?", "What did we decide?"))
                querySuggestion(t("Что нужно сделать дальше?", "What needs to happen next?"))
                querySuggestion(t("Найти упоминания клиента или проекта", "Find mentions of a client or project"))
            }
        } else if hits.isEmpty {
            ContentUnavailableView(
                t("В источниках ничего не найдено", "No source evidence found"),
                systemImage: "magnifyingglass",
                description: Text(t(
                    "Попробуйте другие слова или расширьте область поиска. SuperDictate не будет выдумывать ответ, если локальные транскрипты его не подтверждают.",
                    "Try different words or broaden the scope. SuperDictate will not fabricate an answer when the local transcripts do not support one."
                ))
            )
            .frame(maxWidth: .infinity, minHeight: 240)
        } else {
            LazyVStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(t("Совпадения в источниках", "Source matches"))
                        .font(SuperDictateDesign.TypeStyle.heading)
                    Spacer()
                    Text("\(hits.count)")
                        .font(SuperDictateDesign.TypeStyle.caption.weight(.medium))
                        .foregroundStyle(SuperDictateDesign.ColorRole.textTertiary)
                }
                .padding(.bottom, SuperDictateDesign.Spacing.inline)

                ForEach(Array(hits.enumerated()), id: \.element.id) { index, hit in
                    EvidenceResultRow(
                        hit: hit,
                        documentTitle: documentTitle(for: hit.recordingID),
                        language: language,
                        action: { onOpenEvidence(hit) }
                    )
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
                t("Поиск по записям", "Search your recordings"),
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
            .foregroundStyle(canSubmit
                             ? SuperDictateDesign.ColorRole.actionPrimary
                             : SuperDictateDesign.ColorRole.textTertiary)
            .disabled(!canSubmit)
            .accessibilityLabel(t("Искать в памяти", "Search memory"))
        }
        .padding(.horizontal, SuperDictateDesign.Spacing.contentGutter)
        .padding(.vertical, SuperDictateDesign.Spacing.compact)
        .frame(
            maxWidth: SuperDictateDesign.Layout.documentMaxReadableWidth
                + (SuperDictateDesign.Spacing.contentGutter * 2)
        )
        .frame(maxWidth: .infinity)
        .background(SuperDictateDesign.ColorRole.canvas)
    }

    private var scopedDocuments: [SuperDictateMemoryDocument] {
        guard !scopeRecordingIDs.isEmpty else { return documents }
        return documents.filter { scopeRecordingIDs.contains($0.recordingID) }
    }

    private var canSubmit: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var scopeDescription: String {
        if scopeRecordingIDs.count == 1 {
            return t(
                "Поиск только по этой записи. Каждый результат ведёт к точному исходному фрагменту.",
                "Searching this recording. Every result links to its exact source segment."
            )
        }
        if !scopeRecordingIDs.isEmpty {
            return t(
                "Поиск по выбранным записям: \(scopeRecordingIDs.count). Каждый результат остаётся связан с источником.",
                "Searching \(scopeRecordingIDs.count) selected recordings. Every result stays source-linked."
            )
        }
        return t(
            "Локальный поиск по записям: \(documents.count). Обращение к облаку не требуется.",
            "Searching \(documents.count) local recording\(documents.count == 1 ? "" : "s"). No cloud call is required."
        )
    }

    private func querySuggestion(_ title: String) -> some View {
        Button {
            query = title
            submit(title)
        } label: {
            HStack(spacing: SuperDictateDesign.Spacing.inline) {
                Text(title)
                    .font(SuperDictateDesign.TypeStyle.interface)
                    .foregroundStyle(SuperDictateDesign.ColorRole.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(SuperDictateDesign.ColorRole.textTertiary)
            }
            .padding(.vertical, SuperDictateDesign.Spacing.inline)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func submit(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        query = trimmed
        submittedQuery = trimmed
        hits = SuperDictateLocalMemoryIndex(documents: documents).search(
            SuperDictateMemoryQuery(
                text: trimmed,
                recordingIDs: scopeRecordingIDs,
                maximumResults: 12
            )
        )
    }

    private func documentTitle(for recordingID: UUID) -> String {
        documents.first { $0.recordingID == recordingID }?.title
            ?? t("Запись", "Recording")
    }
}

private struct EvidenceResultRow: View {
    let hit: SuperDictateMemorySearchHit
    let documentTitle: String
    let language: SuperDictateInterfaceLanguage
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: SuperDictateDesign.Spacing.component) {
                sourceMarker
                    .frame(width: 56, alignment: .leading)

                VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.micro) {
                    Text(hit.excerpt)
                        .font(SuperDictateDesign.TypeStyle.body)
                        .foregroundStyle(SuperDictateDesign.ColorRole.textPrimary)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: SuperDictateDesign.Spacing.inline) {
                        Text(documentTitle)
                        if let speaker = hit.speaker, !speaker.isEmpty {
                            Text("·")
                            Text(speaker)
                        }
                    }
                    .font(SuperDictateDesign.TypeStyle.caption)
                    .foregroundStyle(SuperDictateDesign.ColorRole.textTertiary)
                    .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(SuperDictateDesign.ColorRole.textTertiary)
                    .padding(.top, 3)
            }
            .padding(.vertical, SuperDictateDesign.Spacing.compact)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var sourceMarker: some View {
        if let start = hit.startMilliseconds {
            Text(formatTimestamp(start))
                .font(SuperDictateDesign.TypeStyle.timestamp)
                .foregroundStyle(SuperDictateDesign.ColorRole.textTertiary)
        } else {
            Image(systemName: "text.quote")
                .foregroundStyle(SuperDictateDesign.ColorRole.textTertiary)
        }
    }

    private var accessibilityLabel: String {
        if let start = hit.startMilliseconds {
            return language == .russian
                ? "Открыть \(documentTitle) на \(formatTimestamp(start))"
                : "Open \(documentTitle) at \(formatTimestamp(start))"
        }
        return language == .russian
            ? "Открыть источник в \(documentTitle)"
            : "Open source in \(documentTitle)"
    }
}

private func formatTimestamp(_ milliseconds: Int64) -> String {
    let totalSeconds = max(0, milliseconds / 1_000)
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    let seconds = totalSeconds % 60
    if hours > 0 {
        return String(format: "%lld:%02lld:%02lld", hours, minutes, seconds)
    }
    return String(format: "%02lld:%02lld", minutes, seconds)
}
