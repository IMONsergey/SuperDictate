import SwiftUI
import SuperDictateCore

public struct SuperDictateMainView: View {
    private let snapshot: SuperDictateProductSnapshot
    private let language: SuperDictateInterfaceLanguage
    private let onCommand: (SuperDictateCommand) -> Void

    @State private var destination: SuperDictateDestination = .today
    @State private var selectedRecordingID: UUID?
    @State private var recordingSection: SuperDictateRecordingSection = .summary

    public init(
        snapshot: SuperDictateProductSnapshot,
        language: SuperDictateInterfaceLanguage = .english,
        onCommand: @escaping (SuperDictateCommand) -> Void = { _ in }
    ) {
        self.snapshot = snapshot
        self.language = language
        self.onCommand = onCommand
    }

    public var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(
                    min: SuperDictateDesign.Layout.sidebarMinWidth,
                    ideal: SuperDictateDesign.Layout.sidebarIdealWidth,
                    max: SuperDictateDesign.Layout.sidebarMaxWidth
                )
        } detail: {
            detail
                .background(SuperDictateDesign.ColorRole.canvas)
        }
        .frame(minWidth: 840, minHeight: 600)
        .environment(\.locale, interfaceLocale)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if snapshot.status == .needsAttention {
                    Button {
                        onCommand(.openSystemStatus)
                    } label: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(SuperDictateDesign.ColorRole.warning)
                    }
                    .buttonStyle(.plain)
                    .help(snapshot.issueMessage ?? copy.openSystemStatus)
                }

                Menu {
                    Button(copy.systemStatus) {
                        onCommand(.openSystemStatus)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .help(copy.more)

                Button {
                    onCommand(snapshot.primaryCaptureCommand)
                } label: {
                    Label(
                        snapshot.isCaptureActive ? copy.stop : copy.record,
                        systemImage: snapshot.isCaptureActive ? "stop.fill" : "waveform"
                    )
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .help(snapshot.isCaptureActive ? copy.stopRecordingHelp : copy.startRecordingHelp)
                .disabled(!snapshot.isPrimaryCaptureCommandEnabled)
            }
        }
    }

    private var copy: SuperDictateCopy {
        SuperDictateCopy(language: language)
    }

    private var interfaceLocale: Locale {
        language == .russian ? Locale(identifier: "ru_RU") : Locale(identifier: "en_US")
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List {
                ForEach(SuperDictateDestination.allCases) { item in
                    Button {
                        destination = item
                        selectedRecordingID = nil
                    } label: {
                        Label(item.title(copy: copy), systemImage: item.symbolName)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(destination == item && selectedRecordingID == nil
                                     ? SuperDictateDesign.ColorRole.actionPrimary
                                     : SuperDictateDesign.ColorRole.textPrimary)
                }
            }
            .listStyle(.sidebar)

            Divider()

            Button {
                onCommand(.openSettings)
            } label: {
                Label(copy.settings, systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, SuperDictateDesign.Spacing.component)
            .padding(.vertical, SuperDictateDesign.Spacing.compact)
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let selectedRecording {
            RecordingDetailView(
                recording: selectedRecording,
                tasks: snapshot.tasks.filter { $0.sourceRecordingID == selectedRecording.id },
                section: $recordingSection,
                copy: copy,
                onClose: { selectedRecordingID = nil },
                onCommand: onCommand
            )
        } else {
            switch destination {
            case .today:
                TodayView(
                    snapshot: snapshot,
                    copy: copy,
                    openRecording: openRecording,
                    onCommand: onCommand
                )
            case .library:
                LibraryView(recordings: snapshot.recordings, copy: copy, openRecording: openRecording)
            case .tasks:
                TasksView(tasks: snapshot.tasks, copy: copy, onCommand: onCommand)
            case .ask:
                AskView(copy: copy)
            }
        }
    }

    private var selectedRecording: SuperDictateRecording? {
        guard let selectedRecordingID else { return nil }
        return snapshot.recordings.first { $0.id == selectedRecordingID }
    }

    private func openRecording(_ recording: SuperDictateRecording) {
        selectedRecordingID = recording.id
        recordingSection = recording.summary?.isEmpty == false ? .summary : .transcript
        onCommand(.openRecording(recording.id))
    }
}

private struct TodayView: View {
    let snapshot: SuperDictateProductSnapshot
    let copy: SuperDictateCopy
    let openRecording: (SuperDictateRecording) -> Void
    let onCommand: (SuperDictateCommand) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.section) {
                VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.inline) {
                    Text(copy.today)
                        .font(SuperDictateDesign.TypeStyle.display)
                    Text(todaySubtitle)
                        .font(SuperDictateDesign.TypeStyle.body)
                        .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
                }

                if snapshot.isCaptureActive {
                    RecordingNowRow(startedAt: snapshot.activeRecordingStartedAt, copy: copy)
                } else if snapshot.status == .transcribing {
                    ProcessingRow(copy: copy)
                } else if let issue = snapshot.issueMessage {
                    AttentionRow(message: issue)
                } else if snapshot.recordings.isEmpty && snapshot.tasks.isEmpty {
                    EmptyTodayView(copy: copy, onRecord: { onCommand(.startRecording) })
                }

                if !snapshot.attentionRecordings.isEmpty {
                    DocumentSection(title: copy.sectionNeedsAttention) {
                        ForEach(snapshot.attentionRecordings) { recording in
                            RecordingRow(recording: recording, action: { openRecording(recording) })
                        }
                    }
                }

                if !snapshot.actionableTasks.isEmpty {
                    DocumentSection(title: copy.tasks) {
                        ForEach(snapshot.actionableTasks.prefix(5)) { task in
                            TaskRow(task: task, onToggle: { onCommand(.toggleTask(task.id)) })
                        }
                    }
                }

                if !snapshot.recentRecordings.isEmpty {
                    DocumentSection(title: copy.sectionRecent) {
                        ForEach(snapshot.recentRecordings) { recording in
                            RecordingRow(recording: recording, action: { openRecording(recording) })
                        }
                    }
                }
            }
            .padding(SuperDictateDesign.Spacing.contentGutter)
            .superDictateReadableDocument()
        }
        .navigationTitle(copy.today)
    }

    private var todaySubtitle: String {
        switch snapshot.status {
        case .recording: return copy.recordingLocally
        case .transcribing: return copy.transcribingLatest
        case .needsAttention: return copy.attentionSubtitle
        case .idle, .ready: return copy.todayDefaultSubtitle
        }
    }
}

private struct LibraryView: View {
    let recordings: [SuperDictateRecording]
    let copy: SuperDictateCopy
    let openRecording: (SuperDictateRecording) -> Void

    var body: some View {
        Group {
            if recordings.isEmpty {
                ContentUnavailableView(
                    copy.noRecordings,
                    systemImage: "waveform",
                    description: Text(copy.noRecordingsDetail)
                )
            } else {
                List(recordings) { recording in
                    RecordingRow(recording: recording, action: { openRecording(recording) })
                }
            }
        }
        .navigationTitle(copy.library)
    }
}

private struct TasksView: View {
    let tasks: [SuperDictateTask]
    let copy: SuperDictateCopy
    let onCommand: (SuperDictateCommand) -> Void

    var body: some View {
        Group {
            if tasks.isEmpty {
                ContentUnavailableView(
                    copy.noTasks,
                    systemImage: "checkmark.circle",
                    description: Text(copy.noTasksDetail)
                )
            } else {
                List(tasks) { task in
                    TaskRow(task: task, onToggle: { onCommand(.toggleTask(task.id)) })
                }
            }
        }
        .navigationTitle(copy.tasks)
    }
}

private struct AskView: View {
    let copy: SuperDictateCopy

    var body: some View {
        ContentUnavailableView(
            copy.askUnavailable,
            systemImage: "text.bubble",
            description: Text(copy.askUnavailableDetail)
        )
        .navigationTitle(copy.ask)
    }
}

private struct RecordingDetailView: View {
    let recording: SuperDictateRecording
    let tasks: [SuperDictateTask]
    @Binding var section: SuperDictateRecordingSection
    let copy: SuperDictateCopy
    let onClose: () -> Void
    let onCommand: (SuperDictateCommand) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.section) {
                VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.compact) {
                    Button(action: onClose) {
                        Label(copy.back, systemImage: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)

                    Text(recording.title)
                        .font(SuperDictateDesign.TypeStyle.display)
                        .textSelection(.enabled)

                    HStack(spacing: SuperDictateDesign.Spacing.inline) {
                        if let createdAt = recording.createdAt {
                            Text(createdAt, format: .dateTime.day().month().year().hour().minute())
                        }
                        if let duration = recording.durationSeconds {
                            Text(durationLabel(duration))
                        }
                        if !recording.people.isEmpty {
                            Text(recording.people.joined(separator: ", "))
                        }
                    }
                    .font(SuperDictateDesign.TypeStyle.caption)
                    .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
                }

                Picker(copy.view, selection: $section) {
                    ForEach(SuperDictateRecordingSection.allCases) { item in
                        Text(item.title(copy: copy)).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)

                switch section {
                case .summary:
                    Text(summaryText)
                        .font(SuperDictateDesign.TypeStyle.body)
                        .lineSpacing(5)
                        .textSelection(.enabled)
                case .transcript:
                    TranscriptDocument(text: recording.transcript, copy: copy)
                case .tasks:
                    if tasks.isEmpty {
                        Text(copy.noVerifiedTasks)
                            .font(SuperDictateDesign.TypeStyle.body)
                            .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
                    } else {
                        ForEach(tasks) { task in
                            TaskRow(task: task, onToggle: { onCommand(.toggleTask(task.id)) })
                        }
                    }
                }
            }
            .padding(SuperDictateDesign.Spacing.contentGutter)
            .superDictateReadableDocument()
        }
        .navigationTitle(recording.title)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    onCommand(.copyTranscript(recording.id))
                } label: {
                    Label(copy.copyTranscript, systemImage: "doc.on.doc")
                }
            }
        }
    }

    private var summaryText: String {
        guard let summary = recording.summary?.trimmingCharacters(in: .whitespacesAndNewlines),
              !summary.isEmpty else {
            return copy.noSummary
        }
        return summary
    }
}

private struct TranscriptDocument: View {
    let text: String
    let copy: SuperDictateCopy

    var body: some View {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(copy.noTranscript)
                .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
        } else {
            Text(text)
                .font(SuperDictateDesign.TypeStyle.body)
                .lineSpacing(5)
                .textSelection(.enabled)
        }
    }
}

private struct DocumentSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.compact) {
            Text(title)
                .font(SuperDictateDesign.TypeStyle.heading)
            content
        }
    }
}

private struct RecordingRow: View {
    let recording: SuperDictateRecording
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: SuperDictateDesign.Spacing.compact) {
                VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.micro) {
                    Text(recording.title)
                        .font(SuperDictateDesign.TypeStyle.interfaceMedium)
                        .foregroundStyle(SuperDictateDesign.ColorRole.textPrimary)
                        .lineLimit(1)
                    if let createdAt = recording.createdAt {
                        Text(createdAt, format: .dateTime.day().month().hour().minute())
                            .font(SuperDictateDesign.TypeStyle.caption)
                            .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
                    }
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
        .padding(.vertical, SuperDictateDesign.Spacing.micro)
    }
}

private struct TaskRow: View {
    let task: SuperDictateTask
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: SuperDictateDesign.Spacing.compact) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted
                                     ? SuperDictateDesign.ColorRole.success
                                     : SuperDictateDesign.ColorRole.textTertiary)
                VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.micro) {
                    Text(task.title)
                        .font(SuperDictateDesign.TypeStyle.interface)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted
                                         ? SuperDictateDesign.ColorRole.textSecondary
                                         : SuperDictateDesign.ColorRole.textPrimary)
                    if let excerpt = task.sourceExcerpt, !excerpt.isEmpty {
                        Text(excerpt)
                            .font(SuperDictateDesign.TypeStyle.caption)
                            .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, SuperDictateDesign.Spacing.micro)
    }
}

private struct RecordingNowRow: View {
    let startedAt: Date?
    let copy: SuperDictateCopy

    var body: some View {
        HStack(spacing: SuperDictateDesign.Spacing.compact) {
            Circle()
                .fill(SuperDictateDesign.ColorRole.recording)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.micro) {
                Text(copy.recording)
                    .font(SuperDictateDesign.TypeStyle.interfaceMedium)
                if let startedAt {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(durationLabel(context.date.timeIntervalSince(startedAt)))
                            .font(SuperDictateDesign.TypeStyle.timestamp)
                            .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(copy.recordingAccessibility)
    }
}

private struct ProcessingRow: View {
    let copy: SuperDictateCopy

    var body: some View {
        HStack(spacing: SuperDictateDesign.Spacing.compact) {
            ProgressView()
                .controlSize(.small)
            Text(copy.processingLatest)
                .font(SuperDictateDesign.TypeStyle.interface)
        }
    }
}

private struct AttentionRow: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(SuperDictateDesign.TypeStyle.interface)
            .foregroundStyle(SuperDictateDesign.ColorRole.warning)
    }
}

private struct EmptyTodayView: View {
    let copy: SuperDictateCopy
    let onRecord: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.component) {
            Text(copy.noAttention)
                .font(SuperDictateDesign.TypeStyle.heading)
            Button(copy.startRecording, action: onRecord)
                .buttonStyle(.borderedProminent)
        }
    }
}

private func durationLabel(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded(.down)))
    let hours = total / 3_600
    let minutes = (total % 3_600) / 60
    let remainder = total % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, remainder)
    }
    return String(format: "%02d:%02d", minutes, remainder)
}

private extension SuperDictateDestination {
    func title(copy: SuperDictateCopy) -> String {
        switch self {
        case .today: return copy.today
        case .library: return copy.library
        case .tasks: return copy.tasks
        case .ask: return copy.ask
        }
    }

    var symbolName: String {
        switch self {
        case .today: return "sun.max"
        case .library: return "doc.text"
        case .tasks: return "checkmark.circle"
        case .ask: return "text.bubble"
        }
    }
}

private extension SuperDictateRecordingSection {
    func title(copy: SuperDictateCopy) -> String {
        switch self {
        case .summary: return copy.summary
        case .transcript: return copy.transcript
        case .tasks: return copy.tasks
        }
    }
}
