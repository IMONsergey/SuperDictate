import SwiftUI
import SuperDictateCore

public struct SuperDictateMainView: View {
    private let snapshot: SuperDictateProductSnapshot
    private let onCommand: (SuperDictateCommand) -> Void

    @State private var destination: SuperDictateDestination = .today
    @State private var selectedRecordingID: UUID?
    @State private var recordingSection: SuperDictateRecordingSection = .summary

    public init(
        snapshot: SuperDictateProductSnapshot,
        onCommand: @escaping (SuperDictateCommand) -> Void = { _ in }
    ) {
        self.snapshot = snapshot
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
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if snapshot.status == .needsAttention {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(SuperDictateDesign.ColorRole.warning)
                        .help(snapshot.issueMessage ?? "SuperDictate needs attention")
                }

                Button {
                    onCommand(snapshot.primaryCaptureCommand)
                } label: {
                    Label(
                        snapshot.isCaptureActive ? "Stop" : "Record",
                        systemImage: snapshot.isCaptureActive ? "stop.fill" : "waveform"
                    )
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .help(snapshot.isCaptureActive ? "Stop recording" : "Start recording")
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List {
                ForEach(SuperDictateDestination.allCases) { item in
                    Button {
                        destination = item
                        selectedRecordingID = nil
                    } label: {
                        Label(item.title, systemImage: item.symbolName)
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
                Label("Settings", systemImage: "gearshape")
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
                onClose: { selectedRecordingID = nil },
                onCommand: onCommand
            )
        } else {
            switch destination {
            case .today:
                TodayView(
                    snapshot: snapshot,
                    openRecording: openRecording,
                    onCommand: onCommand
                )
            case .library:
                LibraryView(recordings: snapshot.recordings, openRecording: openRecording)
            case .tasks:
                TasksView(tasks: snapshot.tasks, onCommand: onCommand)
            case .ask:
                AskView()
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
    let openRecording: (SuperDictateRecording) -> Void
    let onCommand: (SuperDictateCommand) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.section) {
                VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.inline) {
                    Text("Today")
                        .font(SuperDictateDesign.TypeStyle.display)
                    Text(todaySubtitle)
                        .font(SuperDictateDesign.TypeStyle.body)
                        .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
                }

                if snapshot.isCaptureActive {
                    RecordingNowRow(startedAt: snapshot.activeRecordingStartedAt)
                } else if snapshot.status == .transcribing {
                    ProcessingRow()
                } else if let issue = snapshot.issueMessage {
                    AttentionRow(message: issue)
                } else if snapshot.recordings.isEmpty && snapshot.tasks.isEmpty {
                    EmptyTodayView(onRecord: { onCommand(.startRecording) })
                }

                if !snapshot.attentionRecordings.isEmpty {
                    DocumentSection(title: "Needs attention") {
                        ForEach(snapshot.attentionRecordings) { recording in
                            RecordingRow(recording: recording, action: { openRecording(recording) })
                        }
                    }
                }

                if !snapshot.actionableTasks.isEmpty {
                    DocumentSection(title: "Tasks") {
                        ForEach(snapshot.actionableTasks.prefix(5)) { task in
                            TaskRow(task: task, onToggle: { onCommand(.toggleTask(task.id)) })
                        }
                    }
                }

                if !snapshot.recentRecordings.isEmpty {
                    DocumentSection(title: "Recent") {
                        ForEach(snapshot.recentRecordings) { recording in
                            RecordingRow(recording: recording, action: { openRecording(recording) })
                        }
                    }
                }
            }
            .padding(SuperDictateDesign.Spacing.contentGutter)
            .superDictateReadableDocument()
        }
        .navigationTitle("Today")
    }

    private var todaySubtitle: String {
        switch snapshot.status {
        case .recording: return "Recording locally."
        case .transcribing: return "Turning your latest recording into text."
        case .needsAttention: return "One item needs your attention."
        case .idle, .ready: return "Record something or continue where you left off."
        }
    }
}

private struct LibraryView: View {
    let recordings: [SuperDictateRecording]
    let openRecording: (SuperDictateRecording) -> Void

    var body: some View {
        Group {
            if recordings.isEmpty {
                ContentUnavailableView(
                    "No recordings yet",
                    systemImage: "waveform",
                    description: Text("Your dictations and captured conversations will appear here.")
                )
            } else {
                List(recordings) { recording in
                    RecordingRow(recording: recording, action: { openRecording(recording) })
                }
            }
        }
        .navigationTitle("Library")
    }
}

private struct TasksView: View {
    let tasks: [SuperDictateTask]
    let onCommand: (SuperDictateCommand) -> Void

    var body: some View {
        Group {
            if tasks.isEmpty {
                ContentUnavailableView(
                    "No tasks",
                    systemImage: "checkmark.circle",
                    description: Text("Verified actions from recordings will appear here.")
                )
            } else {
                List(tasks) { task in
                    TaskRow(task: task, onToggle: { onCommand(.toggleTask(task.id)) })
                }
            }
        }
        .navigationTitle("Tasks")
    }
}

private struct AskView: View {
    var body: some View {
        ContentUnavailableView(
            "Ask is not connected yet",
            systemImage: "text.bubble",
            description: Text("This surface will ship only with evidence-backed answers and source citations. No fake chat UI in the meantime.")
        )
        .navigationTitle("Ask")
    }
}

private struct RecordingDetailView: View {
    let recording: SuperDictateRecording
    let tasks: [SuperDictateTask]
    @Binding var section: SuperDictateRecordingSection
    let onClose: () -> Void
    let onCommand: (SuperDictateCommand) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.section) {
                VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.compact) {
                    Button(action: onClose) {
                        Label("Back", systemImage: "chevron.left")
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

                Picker("View", selection: $section) {
                    ForEach(SuperDictateRecordingSection.allCases) { item in
                        Text(item.title).tag(item)
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
                    TranscriptDocument(text: recording.transcript)
                case .tasks:
                    if tasks.isEmpty {
                        Text("No verified tasks from this recording.")
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
                    Label("Copy transcript", systemImage: "doc.on.doc")
                }
            }
        }
    }

    private var summaryText: String {
        guard let summary = recording.summary?.trimmingCharacters(in: .whitespacesAndNewlines),
              !summary.isEmpty else {
            return "No summary yet."
        }
        return summary
    }
}

private struct TranscriptDocument: View {
    let text: String

    var body: some View {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text("No transcript yet.")
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

    var body: some View {
        HStack(spacing: SuperDictateDesign.Spacing.compact) {
            Circle()
                .fill(SuperDictateDesign.ColorRole.recording)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.micro) {
                Text("Recording")
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
        .accessibilityLabel("Recording in progress")
    }
}

private struct ProcessingRow: View {
    var body: some View {
        HStack(spacing: SuperDictateDesign.Spacing.compact) {
            ProgressView()
                .controlSize(.small)
            Text("Transcribing latest recording…")
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
    let onRecord: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.component) {
            Text("Nothing needs your attention.")
                .font(SuperDictateDesign.TypeStyle.heading)
            Button("Start recording", action: onRecord)
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
    var title: String {
        switch self {
        case .today: return "Today"
        case .library: return "Library"
        case .tasks: return "Tasks"
        case .ask: return "Ask"
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
    var title: String {
        switch self {
        case .summary: return "Summary"
        case .transcript: return "Transcript"
        case .tasks: return "Tasks"
        }
    }
}
