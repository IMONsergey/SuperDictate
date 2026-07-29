import SwiftUI
import SuperDictateCore

public struct SuperDictateWorkbenchView: View {
    private let state: SuperDictateWorkbenchState
    private let onCommand: (SuperDictateWorkbenchCommand) -> Void
    private let onSelectTab: (SuperDictateWorkbenchTab) -> Void

    public init(
        state: SuperDictateWorkbenchState,
        onCommand: @escaping (SuperDictateWorkbenchCommand) -> Void = { _ in },
        onSelectTab: @escaping (SuperDictateWorkbenchTab) -> Void = { _ in }
    ) {
        self.state = state
        self.onCommand = onCommand
        self.onSelectTab = onSelectTab
    }

    public var body: some View {
        HStack(spacing: 0) {
            WorkbenchSidebar(state: state, onSelectTab: onSelectTab)
                .frame(width: 224)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                WorkbenchHeader(state: state, onCommand: onCommand)
                WorkbenchMetrics(metrics: state.headlineMetrics)
                WorkbenchContent(state: state)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()

            WorkbenchInspector(state: state)
                .frame(width: 300)
        }
        .frame(minWidth: 980, minHeight: 680)
        .background(WorkbenchStyle.background)
    }
}

private struct WorkbenchSidebar: View {
    let state: SuperDictateWorkbenchState
    let onSelectTab: (SuperDictateWorkbenchTab) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Text("S")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.teal)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("SuperDictate")
                        .font(.headline.weight(.bold))
                    Text(state.status.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 6) {
                ForEach(state.availableTabs, id: \.rawValue) { tab in
                    Button {
                        onSelectTab(tab)
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: tab.symbolName)
                                .frame(width: 18)
                            Text(tab.displayName)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                        .foregroundStyle(state.selectedTab == tab ? Color.teal : Color.primary)
                        .background(state.selectedTab == tab ? Color.teal.opacity(0.12) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .leading, spacing: 8) {
                Text("Local models")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                ReadinessLine(state: state, capability: .transcription, title: "Transcription")
                ReadinessLine(state: state, capability: .summarization, title: "Summary")
                ReadinessLine(state: state, capability: .actionExtraction, title: "Actions")
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }
}

private struct WorkbenchHeader: View {
    let state: SuperDictateWorkbenchState
    let onCommand: (SuperDictateWorkbenchCommand) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Badge(text: state.status.displayName, tone: state.status.tone)
                    ForEach(state.badges, id: \.id) { badge in
                        Badge(text: badge.label, tone: badge.tone)
                    }
                }

                Text(title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                onCommand(state.primaryCommand)
            } label: {
                Text(state.primaryCommand.title)
                    .font(.headline.weight(.semibold))
                    .frame(minWidth: 112)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!state.primaryCommand.isEnabled)
        }
    }

    private var title: String {
        switch state.status {
        case .idle: return "Ready for local capture"
        case .recording: return "Recording locally"
        case .processing: return "Processing on device"
        case .ready: return "Transcript ready"
        case .needsReview: return "Review extracted work"
        case .needsAttention: return "Recovery needed"
        case .failed: return "Recording failed"
        }
    }

    private var subtitle: String {
        if let summary = state.summary {
            return "\(summary.sections.count) summary sections · \(state.actionItems.count) actions · \(state.requiresReviewCount) pending review"
        }
        if let transcript = state.transcript {
            return "\(transcript.segments.count) transcript segments · \(state.actionItems.count) actions"
        }
        return "Audio, transcripts, summaries and model state stay local unless policy allows transfer."
    }
}

private struct WorkbenchMetrics: View {
    let metrics: [SuperDictateWorkbenchMetric]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(metrics, id: \.id) { metric in
                VStack(alignment: .leading, spacing: 5) {
                    Text(metric.label.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(metric.value)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(metric.tone.tint)
                    Text(metric.detail ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
                .padding(12)
                .background(metric.tone.fill)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

private struct WorkbenchContent: View {
    let state: SuperDictateWorkbenchState

    var body: some View {
        Group {
            switch state.selectedTab {
            case .recorder:
                RecorderPanel(state: state)
            case .processing:
                ProcessingPanel(state: state)
            case .transcript:
                TranscriptPanel(transcript: state.transcript)
            case .summary:
                SummaryPanel(summary: state.summary)
            case .actions:
                ActionsPanel(insights: state.insights, actionItems: state.actionItems)
            case .models:
                ModelsPanel(modelStates: state.modelStates)
            }
        }
    }
}

private struct RecorderPanel: View {
    let state: SuperDictateWorkbenchState

    var body: some View {
        Panel(title: "Recorder", subtitle: "Local package and capture state") {
            VStack(alignment: .leading, spacing: 14) {
                WaveformBlock(isRecording: state.status == .recording)

                HStack(spacing: 10) {
                    InfoTile(title: "Package", value: state.manifest?.localState.rawValue ?? "idle", tone: .neutral)
                    InfoTile(title: "Bytes", value: formattedBytes(state.manifest?.totalByteCount), tone: .neutral)
                    InfoTile(title: "Markers", value: "\(state.manifest?.markers.count ?? 0)", tone: .accent)
                    InfoTile(title: "Recovery", value: state.recoveryState?.rawValue ?? "clean", tone: .positive)
                }
            }
        }
    }
}

private struct ProcessingPanel: View {
    let state: SuperDictateWorkbenchState

    var body: some View {
        Panel(title: "Processing", subtitle: "Transcription, summary and extraction") {
            VStack(alignment: .leading, spacing: 14) {
                ProgressView(value: state.processingProgress)
                    .progressViewStyle(.linear)

                ForEach(LocalAIProcessingStage.displayOrder, id: \.rawValue) { stage in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(stageTone(stage).tint)
                            .frame(width: 10, height: 10)
                        Text(stage.displayName)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(stageLabel(stage))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(stageTone(stage).tint)
                    }
                    .padding(10)
                    .background(stageTone(stage).fill)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                ForEach(state.issues, id: \.id) { issue in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(issue.stage.displayName)
                                .font(.subheadline.weight(.semibold))
                            Text(issue.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    private func stageTone(_ stage: LocalAIProcessingStage) -> SuperDictateWorkbenchTone {
        guard let active = state.activeProcessingStage else {
            return state.processingProgress >= 1 ? .positive : .neutral
        }
        if active == stage { return .accent }
        let activeIndex = LocalAIProcessingStage.displayOrder.firstIndex(of: active) ?? 0
        let stageIndex = LocalAIProcessingStage.displayOrder.firstIndex(of: stage) ?? 0
        return stageIndex < activeIndex ? .positive : .neutral
    }

    private func stageLabel(_ stage: LocalAIProcessingStage) -> String {
        guard let active = state.activeProcessingStage else {
            return state.processingProgress >= 1 ? "done" : "waiting"
        }
        if active == stage { return "active" }
        let activeIndex = LocalAIProcessingStage.displayOrder.firstIndex(of: active) ?? 0
        let stageIndex = LocalAIProcessingStage.displayOrder.firstIndex(of: stage) ?? 0
        return stageIndex < activeIndex ? "done" : "waiting"
    }
}

private struct TranscriptPanel: View {
    let transcript: LocalTranscript?

    var body: some View {
        Panel(title: "Transcript", subtitle: "Timed source text") {
            if let transcript, !transcript.segments.isEmpty {
                VStack(spacing: 8) {
                    ForEach(transcript.segments, id: \.id) { segment in
                        HStack(alignment: .top, spacing: 12) {
                            Text(timeRange(segment))
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(Color.teal)
                                .frame(width: 96, alignment: .leading)
                            Text(segment.text)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if let confidence = segment.confidence {
                                Badge(text: "\(Int(confidence * 100))%", tone: confidence > 0.8 ? .positive : .warning)
                            }
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.035))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            } else {
                EmptyPanel(title: "No transcript yet", detail: "Record locally and run transcription.")
            }
        }
    }
}

private struct SummaryPanel: View {
    let summary: LocalRecordingSummary?

    var body: some View {
        Panel(title: "Summary", subtitle: "Generated text with evidence") {
            if let summary {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(summary.sections, id: \.id) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(.headline.weight(.semibold))
                            ForEach(section.bullets, id: \.self) { bullet in
                                Text("• \(bullet)")
                                    .font(.body)
                            }
                            Text("\(section.evidence.count) evidence spans")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.035))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            } else {
                EmptyPanel(title: "No summary yet", detail: "Install or enable a local summary model.")
            }
        }
    }
}

private struct ActionsPanel: View {
    let insights: [ExtractedInsight]
    let actionItems: [ActionItem]

    var body: some View {
        Panel(title: "Actions", subtitle: "Review queue for decisions, tasks and risks") {
            if insights.isEmpty && actionItems.isEmpty {
                EmptyPanel(title: "No action candidates", detail: "Extraction will populate this queue.")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(actionItems, id: \.id) { action in
                        ActionRow(title: action.title, subtitle: action.synchronizationState.rawValue, tone: .accent)
                    }
                    ForEach(insights, id: \.id) { insight in
                        ActionRow(title: insight.statement, subtitle: insight.kind.rawValue, tone: insight.kind.tone)
                    }
                }
            }
        }
    }
}

private struct ModelsPanel: View {
    let modelStates: [LocalModelRuntimeState]

    var body: some View {
        Panel(title: "Models", subtitle: "Local adapter status") {
            VStack(spacing: 10) {
                ForEach(modelStates, id: \.id) { modelState in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: modelState.model.adapterKind.symbolName)
                                .frame(width: 24)
                                .foregroundStyle(modelState.installState.tone.tint)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(modelState.model.displayName)
                                    .font(.headline.weight(.semibold))
                                Text(modelState.model.licenseSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Badge(text: modelState.installState.displayName, tone: modelState.installState.tone)
                        }

                        if modelState.installState == .downloading {
                            ProgressView(value: modelState.downloadProgress)
                                .progressViewStyle(.linear)
                        }
                    }
                    .padding(12)
                    .background(modelState.installState.tone.fill)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }
}

private struct WorkbenchInspector: View {
    let state: SuperDictateWorkbenchState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Panel(title: "Review", subtitle: nil, compact: true) {
                InfoTile(title: "Needs review", value: "\(state.requiresReviewCount)", tone: state.requiresReviewCount > 0 ? .accent : .positive)
                InfoTile(title: "Issues", value: "\(state.issues.count)", tone: state.issues.isEmpty ? .positive : .warning)
            }

            Panel(title: "Models", subtitle: nil, compact: true) {
                VStack(alignment: .leading, spacing: 8) {
                    ReadinessLine(state: state, capability: .transcription, title: "Transcription")
                    ReadinessLine(state: state, capability: .summarization, title: "Summary")
                    ReadinessLine(state: state, capability: .actionExtraction, title: "Actions")
                }
            }

            Panel(title: "Package", subtitle: nil, compact: true) {
                MiniFact(title: "Recording", value: state.recordingID?.uuidString.prefix(8).description ?? "none")
                MiniFact(title: "Chunks", value: "\(state.manifest?.chunks.count ?? 0)")
                MiniFact(title: "Policy", value: state.manifest?.productPolicy.cloudProcessing.rawValue ?? "local")
            }

            Spacer()
        }
        .padding(16)
        .background(Color.primary.opacity(0.025))
    }
}

private struct Panel<Content: View>: View {
    let title: String
    let subtitle: String?
    let compact: Bool
    let content: Content

    init(
        title: String,
        subtitle: String?,
        compact: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.compact = compact
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font((compact ? Font.subheadline : Font.title3).weight(.bold))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding(compact ? 12 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct Badge: View {
    let text: String
    let tone: SuperDictateWorkbenchTone

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(tone.tint)
            .background(tone.fill)
            .clipShape(Capsule())
    }
}

private struct InfoTile: View {
    let title: String
    let value: String
    let tone: SuperDictateWorkbenchTone

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(tone.tint)
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .padding(12)
        .background(tone.fill)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ReadinessLine: View {
    let state: SuperDictateWorkbenchState
    let capability: LocalAIModelCapability
    let title: String

    var body: some View {
        let ready = state.hasReadyModel(capableOf: capability)
        HStack {
            Circle()
                .fill(ready ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption.weight(.semibold))
            Spacer()
            Text(ready ? "ready" : "missing")
                .font(.caption2.weight(.bold))
                .foregroundStyle(ready ? Color.green : Color.orange)
        }
    }
}

private struct MiniFact: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
        }
    }
}

private struct EmptyPanel: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline.weight(.semibold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .padding(14)
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct WaveformBlock: View {
    let isRecording: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.08, blue: 0.12),
                            Color(red: 0.08, green: 0.12, blue: 0.17),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            HStack(alignment: .center, spacing: 5) {
                ForEach(0..<44, id: \.self) { index in
                    Capsule()
                        .fill(index % 5 == 0 ? Color.yellow : Color.teal)
                        .frame(width: 4, height: CGFloat(18 + ((index * 17) % 58)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 18)

            Text(isRecording ? "capturing local audio" : "local waveform")
                .font(.caption.monospaced())
                .foregroundStyle(.white.opacity(0.72))
                .padding(12)
        }
        .frame(height: 190)
    }
}

private struct ActionRow: View {
    let title: String
    let subtitle: String
    let tone: SuperDictateWorkbenchTone

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checklist")
                .foregroundStyle(tone.tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(text: "review", tone: tone)
        }
        .padding(12)
        .background(tone.fill)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private enum WorkbenchStyle {
    static let background = LinearGradient(
        colors: [
            Color(red: 0.965, green: 0.972, blue: 0.98),
            Color(red: 0.94, green: 0.955, blue: 0.95),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private func timeRange(_ segment: LocalTranscriptSegment) -> String {
    "\(formatMilliseconds(segment.startOffsetMilliseconds))-\(formatMilliseconds(segment.endOffsetMilliseconds))"
}

private func formatMilliseconds(_ milliseconds: Int64) -> String {
    let totalSeconds = max(0, milliseconds / 1_000)
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%02lld:%02lld", minutes, seconds)
}

private func formattedBytes(_ bytes: Int64?) -> String {
    guard let bytes else {
        return "0 KB"
    }
    let value = Double(bytes)
    if value >= 1_024 * 1_024 {
        return String(format: "%.1f MB", value / 1_024 / 1_024)
    }
    return "\(max(1, Int(value / 1_024))) KB"
}

private extension SuperDictateWorkbenchTab {
    var displayName: String {
        switch self {
        case .recorder: return "Recorder"
        case .processing: return "Processing"
        case .transcript: return "Transcript"
        case .summary: return "Summary"
        case .actions: return "Actions"
        case .models: return "Models"
        }
    }

    var symbolName: String {
        switch self {
        case .recorder: return "waveform"
        case .processing: return "cpu"
        case .transcript: return "text.alignleft"
        case .summary: return "doc.text"
        case .actions: return "checklist"
        case .models: return "square.stack.3d.up"
        }
    }
}

private extension LocalAIProcessingStage {
    static let displayOrder: [LocalAIProcessingStage] = [
        .validatingSource,
        .transcribing,
        .structuring,
        .summarizing,
        .extractingActions,
        .completed,
    ]

    var displayName: String {
        switch self {
        case .validatingSource: return "Validate source"
        case .transcribing: return "Transcribe"
        case .structuring: return "Structure transcript"
        case .summarizing: return "Summarize"
        case .extractingActions: return "Extract actions"
        case .completed: return "Complete"
        }
    }
}

private extension LocalAIAdapterKind {
    var symbolName: String {
        switch self {
        case .ruleBased: return "slider.horizontal.3"
        case .whisperCpp, .whisperKit: return "waveform.badge.magnifyingglass"
        case .llamaCpp, .mlx: return "brain.head.profile"
        case .custom: return "shippingbox"
        }
    }
}

private extension LocalModelInstallState {
    var displayName: String {
        rawValue.replacingOccurrences(of: "_", with: " ")
    }

    var tone: SuperDictateWorkbenchTone {
        switch self {
        case .ready: return .positive
        case .downloading: return .accent
        case .notInstalled: return .warning
        case .failed, .disabledByPolicy: return .danger
        }
    }
}

private extension SuperDictateWorkbenchStatus {
    var displayName: String {
        rawValue.replacingOccurrences(of: "_", with: " ")
    }

    var tone: SuperDictateWorkbenchTone {
        switch self {
        case .idle, .ready: return .positive
        case .recording, .processing, .needsReview: return .accent
        case .needsAttention: return .warning
        case .failed: return .danger
        }
    }
}

private extension InsightKind {
    var tone: SuperDictateWorkbenchTone {
        switch self {
        case .decision, .commitment: return .positive
        case .actionItem, .clientCorrection: return .accent
        case .risk: return .warning
        case .openQuestion, .factCandidate, .notableMoment: return .neutral
        }
    }
}

private extension SuperDictateWorkbenchTone {
    var tint: Color {
        switch self {
        case .neutral: return .secondary
        case .positive: return .green
        case .accent: return .teal
        case .warning: return .orange
        case .danger: return .red
        }
    }

    var fill: Color {
        switch self {
        case .neutral: return Color.primary.opacity(0.045)
        case .positive: return Color.green.opacity(0.12)
        case .accent: return Color.teal.opacity(0.13)
        case .warning: return Color.orange.opacity(0.14)
        case .danger: return Color.red.opacity(0.13)
        }
    }
}
