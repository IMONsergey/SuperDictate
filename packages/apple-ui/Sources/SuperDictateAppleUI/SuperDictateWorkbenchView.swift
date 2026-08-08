import SwiftUI
import SuperDictateCore

/// Lightweight native product shell.
///
/// This view intentionally does not expose the complete runtime feature graph.
/// Capture is a global action; models/recovery internals belong in Settings or
/// contextual disclosure; generated content is presented as documents/lists.
public struct SuperDictateWorkbenchView: View {
    private let state: SuperDictateWorkbenchState
    private let onCommand: (SuperDictateWorkbenchCommand) -> Void
    private let onSelectTab: (SuperDictateWorkbenchTab) -> Void

    @State private var destination: PrimaryDestination

    public init(
        state: SuperDictateWorkbenchState,
        onCommand: @escaping (SuperDictateWorkbenchCommand) -> Void = { _ in },
        onSelectTab: @escaping (SuperDictateWorkbenchTab) -> Void = { _ in }
    ) {
        self.state = state
        self.onCommand = onCommand
        self.onSelectTab = onSelectTab
        _destination = State(initialValue: Self.initialDestination(for: state.selectedTab))
    }

    public var body: some View {
        NavigationSplitView {
            List(PrimaryDestination.allCases, selection: $destination) { item in
                Label(item.title, systemImage: item.symbolName)
                    .tag(item)
            }
            .navigationTitle("SuperDictate")
            .navigationSplitViewColumnWidth(
                min: SuperDictateDesign.Layout.sidebarMinWidth,
                ideal: SuperDictateDesign.Layout.sidebarIdealWidth,
                max: SuperDictateDesign.Layout.sidebarMaxWidth
            )
        } detail: {
            detail
                .background(SuperDictateDesign.ColorRole.canvas)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        captureButton
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
        #if os(macOS)
        .frame(minWidth: 780, minHeight: 560)
        #endif
    }

    @ViewBuilder
    private var detail: some View {
        switch destination {
        case .today:
            TodayView(
                state: state,
                onCommand: onCommand,
                openLibrary: { destination = .library },
                openTasks: { destination = .tasks }
            )
        case .library:
            LibraryView(state: state, onSelectTab: onSelectTab)
        case .tasks:
            TasksView(state: state)
        case .ask:
            AskPlaceholderView()
        }
    }

    private var captureButton: some View {
        Button {
            onCommand(captureCommand)
        } label: {
            Label(captureCommand.title, systemImage: state.status == .recording ? "stop.fill" : "record.circle")
        }
        .disabled(!captureCommand.isEnabled)
        .help(state.status == .recording ? "Stop recording" : "Start recording")
        .tint(state.status == .recording ? SuperDictateDesign.ColorRole.recording : SuperDictateDesign.ColorRole.actionPrimary)
    }

    private var captureCommand: SuperDictateWorkbenchCommand {
        if state.status == .recording {
            return SuperDictateWorkbenchCommand(
                id: "stop",
                title: "Stop",
                targetTab: .recorder,
                role: .destructive,
                isEnabled: true
            )
        }

        return SuperDictateWorkbenchCommand(
            id: "record",
            title: "Record",
            targetTab: .recorder,
            role: .primary,
            isEnabled: state.status != .processing
                && state.hasReadyModel(capableOf: .transcription)
        )
    }

    private static func initialDestination(for tab: SuperDictateWorkbenchTab) -> PrimaryDestination {
        switch tab {
        case .actions:
            return .tasks
        case .transcript, .summary:
            return .library
        case .recorder, .processing, .models:
            return .today
        }
    }
}

private enum PrimaryDestination: String, CaseIterable, Identifiable {
    case today
    case library
    case tasks
    case ask

    var id: String { rawValue }

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
        case .library: return "rectangle.stack"
        case .tasks: return "checklist"
        case .ask: return "sparkle.magnifyingglass"
        }
    }
}

private struct TodayView: View {
    let state: SuperDictateWorkbenchState
    let onCommand: (SuperDictateWorkbenchCommand) -> Void
    let openLibrary: () -> Void
    let openTasks: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.section) {
                VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.inline) {
                    Text(headline)
                        .font(SuperDictateDesign.TypeStyle.display)
                    Text(detail)
                        .font(SuperDictateDesign.TypeStyle.body)
                        .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
                }

                if state.status == .needsAttention || state.status == .failed {
                    AttentionRow(
                        title: state.status == .failed ? "Recording needs recovery" : "Something needs attention",
                        detail: state.issues.first?.message ?? "Review the local recovery state before continuing.",
                        actionTitle: "Recover",
                        action: { onCommand(state.primaryCommand) }
                    )
                } else if state.status == .processing {
                    ProcessingRow(state: state)
                }

                if state.requiresReviewCount > 0 {
                    SimpleActionRow(
                        symbol: "checklist",
                        title: "\(state.requiresReviewCount) item\(state.requiresReviewCount == 1 ? "" : "s") need review",
                        detail: "Verify extracted work before scheduling or sharing it.",
                        actionTitle: "Open Tasks",
                        action: openTasks
                    )
                }

                if state.transcript != nil || state.summary != nil {
                    VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.compact) {
                        SectionTitle("Recent")
                        Button(action: openLibrary) {
                            RecordingRow(state: state)
                        }
                        .buttonStyle(.plain)
                    }
                } else if state.status == .idle {
                    ContentUnavailableView(
                        "No recordings yet",
                        systemImage: "waveform",
                        description: Text("Use Record in the toolbar or your global shortcut. Short dictation continues to work without opening this window.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 240)
                }
            }
            .padding(SuperDictateDesign.Spacing.contentGutter)
            .superDictateReadableDocument()
        }
        .navigationTitle("Today")
    }

    private var headline: String {
        switch state.status {
        case .idle: return "Ready when you are"
        case .recording: return "Recording"
        case .processing: return "Processing locally"
        case .ready: return "Latest recording is ready"
        case .needsReview: return "Ready to review"
        case .needsAttention: return "Needs attention"
        case .failed: return "Recovery needed"
        }
    }

    private var detail: String {
        switch state.status {
        case .idle:
            return "Speak anywhere with the global shortcut, or capture a longer conversation from here."
        case .recording:
            return "Audio is being captured locally. Stop from the toolbar or your shortcut."
        case .processing:
            return "The recording is safe locally while transcription and processing continue."
        case .ready:
            return "Open the recording when you want the summary or source transcript."
        case .needsReview:
            return "There are extracted items waiting for a quick human check."
        case .needsAttention, .failed:
            return "The source is kept separate from downstream processing so recovery can remain explicit."
        }
    }
}

private struct LibraryView: View {
    let state: SuperDictateWorkbenchState
    let onSelectTab: (SuperDictateWorkbenchTab) -> Void

    var body: some View {
        Group {
            if state.transcript == nil && state.summary == nil && state.status != .recording && state.status != .processing {
                ContentUnavailableView(
                    "Library is empty",
                    systemImage: "rectangle.stack",
                    description: Text("Record a conversation or complete a dictation to create local history.")
                )
            } else {
                RecordingDetailView(state: state, onSelectTab: onSelectTab)
            }
        }
        .navigationTitle("Library")
    }
}

private struct RecordingDetailView: View {
    let state: SuperDictateWorkbenchState
    let onSelectTab: (SuperDictateWorkbenchTab) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.section) {
                VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.inline) {
                    Text("Latest recording")
                        .font(SuperDictateDesign.TypeStyle.title)

                    HStack(spacing: SuperDictateDesign.Spacing.compact) {
                        Label(durationText, systemImage: "clock")
                        if let model = state.transcript?.modelID, !model.isEmpty {
                            Label(model, systemImage: "waveform")
                        }
                    }
                    .font(SuperDictateDesign.TypeStyle.caption)
                    .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
                }

                Picker("Recording view", selection: recordingTabBinding) {
                    Text("Summary").tag(SuperDictateWorkbenchTab.summary)
                    Text("Transcript").tag(SuperDictateWorkbenchTab.transcript)
                    Text("Tasks").tag(SuperDictateWorkbenchTab.actions)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 420)

                if state.status == .processing {
                    ProcessingRow(state: state)
                }

                recordingContent
            }
            .padding(SuperDictateDesign.Spacing.contentGutter)
            .superDictateReadableDocument()
        }
    }

    private var recordingTabBinding: Binding<SuperDictateWorkbenchTab> {
        Binding(
            get: { selectedRecordingTab },
            set: { onSelectTab($0) }
        )
    }

    private var selectedRecordingTab: SuperDictateWorkbenchTab {
        switch state.selectedTab {
        case .summary, .transcript, .actions:
            return state.selectedTab
        case .recorder, .processing, .models:
            if state.summary != nil { return .summary }
            if state.transcript != nil { return .transcript }
            return .summary
        }
    }

    @ViewBuilder
    private var recordingContent: some View {
        switch selectedRecordingTab {
        case .summary:
            SummaryDocument(summary: state.summary)
        case .transcript:
            TranscriptDocument(transcript: state.transcript)
        case .actions:
            TaskDocument(insights: state.insights, actionItems: state.actionItems)
        case .recorder, .processing, .models:
            EmptyView()
        }
    }

    private var durationText: String {
        formatMilliseconds(
            state.transcript?.durationMilliseconds
                ?? state.manifest?.totalChunkDurationMilliseconds
                ?? 0
        )
    }
}

private struct SummaryDocument: View {
    let summary: LocalRecordingSummary?

    var body: some View {
        if let summary, !summary.sections.isEmpty {
            VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.section) {
                ForEach(Array(summary.sections.enumerated()), id: \.element.id) { index, section in
                    VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.compact) {
                        Text(section.title)
                            .font(SuperDictateDesign.TypeStyle.heading)

                        VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.inline) {
                            ForEach(section.bullets, id: \.self) { bullet in
                                HStack(alignment: .firstTextBaseline, spacing: SuperDictateDesign.Spacing.inline) {
                                    Text("•")
                                        .foregroundStyle(SuperDictateDesign.ColorRole.textTertiary)
                                    Text(bullet)
                                        .font(SuperDictateDesign.TypeStyle.body)
                                        .textSelection(.enabled)
                                }
                            }
                        }

                        if !section.evidence.isEmpty {
                            Text("\(section.evidence.count) source reference\(section.evidence.count == 1 ? "" : "s")")
                                .font(SuperDictateDesign.TypeStyle.caption)
                                .foregroundStyle(SuperDictateDesign.ColorRole.textTertiary)
                        }
                    }

                    if index < summary.sections.count - 1 {
                        Divider()
                    }
                }
            }
        } else {
            ContentUnavailableView(
                "No summary yet",
                systemImage: "doc.text",
                description: Text("The source transcript remains available even when summary processing is not configured.")
            )
            .frame(maxWidth: .infinity, minHeight: 240)
        }
    }
}

private struct TranscriptDocument: View {
    let transcript: LocalTranscript?

    var body: some View {
        if let transcript, !transcript.segments.isEmpty {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(transcript.segments.enumerated()), id: \.element.id) { index, segment in
                    HStack(alignment: .top, spacing: SuperDictateDesign.Spacing.component) {
                        Text(formatMilliseconds(segment.startOffsetMilliseconds))
                            .font(SuperDictateDesign.TypeStyle.timestamp)
                            .foregroundStyle(SuperDictateDesign.ColorRole.textTertiary)
                            .frame(width: 52, alignment: .leading)

                        Text(segment.text)
                            .font(SuperDictateDesign.TypeStyle.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, SuperDictateDesign.Spacing.compact)

                    if index < transcript.segments.count - 1 {
                        Divider()
                    }
                }
            }
        } else {
            ContentUnavailableView(
                "No transcript yet",
                systemImage: "text.alignleft",
                description: Text("Transcription appears here as soon as a local engine returns source text.")
            )
            .frame(maxWidth: .infinity, minHeight: 240)
        }
    }
}

private struct TasksView: View {
    let state: SuperDictateWorkbenchState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.section) {
                VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.inline) {
                    Text("Tasks")
                        .font(SuperDictateDesign.TypeStyle.title)
                    Text("Actions stay linked to the conversation that produced them.")
                        .font(SuperDictateDesign.TypeStyle.body)
                        .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
                }

                TaskDocument(insights: state.insights, actionItems: state.actionItems)
            }
            .padding(SuperDictateDesign.Spacing.contentGutter)
            .superDictateReadableDocument()
        }
        .navigationTitle("Tasks")
    }
}

private struct TaskDocument: View {
    let insights: [ExtractedInsight]
    let actionItems: [ActionItem]

    var body: some View {
        if actionItems.isEmpty && insights.isEmpty {
            ContentUnavailableView(
                "No tasks to review",
                systemImage: "checklist",
                description: Text("Action items extracted from recordings will appear here with their source context.")
            )
            .frame(maxWidth: .infinity, minHeight: 240)
        } else {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(actionItems.enumerated()), id: \.element.id) { index, action in
                    TaskRow(
                        title: action.title,
                        detail: action.synchronizationState.rawValue.replacingOccurrences(of: "_", with: " ")
                    )
                    if index < actionItems.count - 1 || !insights.isEmpty {
                        Divider()
                    }
                }

                ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                    TaskRow(
                        title: insight.statement,
                        detail: insight.kind.rawValue.replacingOccurrences(of: "_", with: " ")
                    )
                    if index < insights.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }
}

private struct TaskRow: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: SuperDictateDesign.Spacing.compact) {
            Image(systemName: "circle")
                .foregroundStyle(SuperDictateDesign.ColorRole.textTertiary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.micro) {
                Text(title)
                    .font(SuperDictateDesign.TypeStyle.body)
                    .textSelection(.enabled)
                Text(detail)
                    .font(SuperDictateDesign.TypeStyle.caption)
                    .foregroundStyle(SuperDictateDesign.ColorRole.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, SuperDictateDesign.Spacing.compact)
    }
}

private struct AskPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Ask is not connected yet",
            systemImage: "sparkle.magnifyingglass",
            description: Text("The macOS shell is ready for a scoped, evidence-backed memory query runtime. No fake chat is shown until that runtime exists.")
        )
        .navigationTitle("Ask")
    }
}

private struct ProcessingRow: View {
    let state: SuperDictateWorkbenchState

    var body: some View {
        VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.inline) {
            HStack {
                Text(state.activeProcessingStage?.displayName ?? "Processing")
                    .font(SuperDictateDesign.TypeStyle.interfaceMedium)
                Spacer()
                Text("\(Int((state.processingProgress * 100).rounded()))%")
                    .font(SuperDictateDesign.TypeStyle.caption)
                    .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
            }
            ProgressView(value: state.processingProgress)
                .progressViewStyle(.linear)
        }
    }
}

private struct RecordingRow: View {
    let state: SuperDictateWorkbenchState

    var body: some View {
        HStack(spacing: SuperDictateDesign.Spacing.compact) {
            Image(systemName: "waveform")
                .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.micro) {
                Text("Latest recording")
                    .font(SuperDictateDesign.TypeStyle.interfaceMedium)
                    .foregroundStyle(SuperDictateDesign.ColorRole.textPrimary)
                Text(recordingDetail)
                    .font(SuperDictateDesign.TypeStyle.caption)
                    .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(SuperDictateDesign.ColorRole.textTertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, SuperDictateDesign.Spacing.inline)
    }

    private var recordingDetail: String {
        let duration = formatMilliseconds(
            state.transcript?.durationMilliseconds
                ?? state.manifest?.totalChunkDurationMilliseconds
                ?? 0
        )
        if state.requiresReviewCount > 0 {
            return "\(duration) · \(state.requiresReviewCount) need review"
        }
        return duration
    }
}

private struct AttentionRow: View {
    let title: String
    let detail: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.compact) {
            Label(title, systemImage: "exclamationmark.triangle")
                .font(SuperDictateDesign.TypeStyle.interfaceMedium)
                .foregroundStyle(SuperDictateDesign.ColorRole.warning)
            Text(detail)
                .font(SuperDictateDesign.TypeStyle.body)
                .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
            Button(actionTitle, action: action)
        }
    }
}

private struct SimpleActionRow: View {
    let symbol: String
    let title: String
    let detail: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: SuperDictateDesign.Spacing.component) {
            Image(systemName: symbol)
                .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.micro) {
                Text(title)
                    .font(SuperDictateDesign.TypeStyle.interfaceMedium)
                Text(detail)
                    .font(SuperDictateDesign.TypeStyle.caption)
                    .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
            }

            Spacer()
            Button(actionTitle, action: action)
        }
        .padding(.vertical, SuperDictateDesign.Spacing.inline)
    }
}

private struct SectionTitle: View {
    private let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(SuperDictateDesign.TypeStyle.heading)
            .foregroundStyle(SuperDictateDesign.ColorRole.textPrimary)
    }
}

private func formatMilliseconds(_ milliseconds: Int64) -> String {
    let totalSeconds = max(0, milliseconds / 1_000)
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
        return String(format: "%lld:%02lld:%02lld", hours, minutes, seconds)
    }
    return String(format: "%02lld:%02lld", minutes, seconds)
}

private extension LocalAIProcessingStage {
    var displayName: String {
        switch self {
        case .validatingSource: return "Preparing source"
        case .transcribing: return "Transcribing"
        case .structuring: return "Structuring transcript"
        case .summarizing: return "Writing summary"
        case .extractingActions: return "Finding actions"
        case .completed: return "Ready"
        }
    }
}
