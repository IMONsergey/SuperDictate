import SwiftUI
import SuperDictateCore

/// Native Library list backed by the same local evidence index used by Ask.
/// Search is deliberately lexical today; the UI does not call it semantic or AI.
public struct SuperDictateSearchableLibraryView: View {
    private let recordings: [SuperDictateRecording]
    private let memoryDocuments: [SuperDictateMemoryDocument]
    private let language: SuperDictateInterfaceLanguage
    private let onOpenRecording: (SuperDictateRecording) -> Void

    @State private var query = ""

    public init(
        recordings: [SuperDictateRecording],
        memoryDocuments: [SuperDictateMemoryDocument],
        language: SuperDictateInterfaceLanguage = .english,
        onOpenRecording: @escaping (SuperDictateRecording) -> Void
    ) {
        self.recordings = recordings
        self.memoryDocuments = memoryDocuments
        self.language = language
        self.onOpenRecording = onOpenRecording
    }

    public var body: some View {
        Group {
            if recordings.isEmpty {
                ContentUnavailableView(
                    copy.noRecordings,
                    systemImage: "waveform",
                    description: Text(copy.noRecordingsDetail)
                )
            } else if visibleRecordings.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List(visibleRecordings) { recording in
                    Button {
                        onOpenRecording(recording)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: SuperDictateDesign.Spacing.compact) {
                            VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.micro) {
                                Text(recording.title)
                                    .font(SuperDictateDesign.TypeStyle.interfaceMedium)
                                    .foregroundStyle(SuperDictateDesign.ColorRole.textPrimary)
                                    .lineLimit(1)

                                HStack(spacing: SuperDictateDesign.Spacing.inline) {
                                    if let createdAt = recording.createdAt {
                                        Text(createdAt, format: .dateTime.day().month().hour().minute())
                                    }
                                    if let duration = recording.durationSeconds {
                                        Text(libraryDurationLabel(duration))
                                    }
                                }
                                .font(SuperDictateDesign.TypeStyle.caption)
                                .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
                            }
                            Spacer()
                            if recording.requiresAttention {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(SuperDictateDesign.ColorRole.warning)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(copy.library)
        .searchable(text: $query, prompt: copy.searchLibrary)
    }

    private var copy: SuperDictateCopy {
        SuperDictateCopy(language: language)
    }

    private var searchableDocuments: [SuperDictateMemoryDocument] {
        if memoryDocuments.isEmpty {
            return recordings.map(SuperDictateMemoryDocument.init(recording:))
        }
        return memoryDocuments
    }

    private var visibleRecordings: [SuperDictateRecording] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return recordings }

        let matchedIDs = Set(
            SuperDictateLocalMemoryIndex(documents: searchableDocuments)
                .matchingDocuments(text: trimmed, maximumResults: 100)
                .map(\.recordingID)
        )
        return recordings.filter { matchedIDs.contains($0.id) }
    }
}

private func libraryDurationLabel(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded(.down)))
    let hours = total / 3_600
    let minutes = (total % 3_600) / 60
    let remainder = total % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, remainder)
    }
    return String(format: "%02d:%02d", minutes, remainder)
}
