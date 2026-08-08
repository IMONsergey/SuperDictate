import SwiftUI
import SuperDictateCore

/// Dedicated model-management surface for Settings.
///
/// Model choice is intentionally removed from the primary workbench chrome.
/// This view keeps recommendation, privacy, install state, size and licensing
/// inspectable without turning normal capture into configuration work.
public struct SuperDictateModelSettingsView: View {
    private let deviceClass: SuperDictateDeviceClass
    private let modelStates: [LocalModelRuntimeState]
    private let selectedTranscriptionModelID: String?
    private let onSelectModel: (String) -> Void
    private let onInstallModel: (String) -> Void
    private let onRemoveModel: (String) -> Void

    public init(
        deviceClass: SuperDictateDeviceClass,
        modelStates: [LocalModelRuntimeState],
        selectedTranscriptionModelID: String?,
        onSelectModel: @escaping (String) -> Void,
        onInstallModel: @escaping (String) -> Void,
        onRemoveModel: @escaping (String) -> Void
    ) {
        self.deviceClass = deviceClass
        self.modelStates = modelStates
        self.selectedTranscriptionModelID = selectedTranscriptionModelID
        self.onSelectModel = onSelectModel
        self.onInstallModel = onInstallModel
        self.onRemoveModel = onRemoveModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.section) {
                header
                modelSection(
                    title: "Speech",
                    detail: "Choose the local engine used for transcription. SuperDictate recommends a default for this device, but never changes models silently.",
                    capability: .transcription
                )
                modelSection(
                    title: "Understanding",
                    detail: "Local summary and extraction models run after transcription. The built-in rules remain available as an offline fallback.",
                    capability: .summarization
                )
            }
            .padding(SuperDictateDesign.Spacing.contentGutter)
            .superDictateReadableDocument()
        }
        .navigationTitle("Models")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.inline) {
            Text("Models")
                .font(SuperDictateDesign.TypeStyle.title)
            Text("Local-first is the default. Downloads and model changes are explicit, and model licensing stays visible before installation.")
                .font(SuperDictateDesign.TypeStyle.body)
                .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
        }
    }

    @ViewBuilder
    private func modelSection(
        title: String,
        detail: String,
        capability: LocalAIModelCapability
    ) -> some View {
        let rows = rowsForCapability(capability)
        VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.compact) {
            VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.micro) {
                Text(title)
                    .font(SuperDictateDesign.TypeStyle.heading)
                Text(detail)
                    .font(SuperDictateDesign.TypeStyle.caption)
                    .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
            }

            if rows.isEmpty {
                Text("No compatible local model is advertised for this device.")
                    .font(SuperDictateDesign.TypeStyle.body)
                    .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
                    .padding(.vertical, SuperDictateDesign.Spacing.compact)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.model.id) { index, row in
                        ModelSettingsRow(
                            row: row,
                            isSelected: selectedTranscriptionModelID == row.model.id,
                            onSelect: { onSelectModel(row.model.id) },
                            onInstall: { onInstallModel(row.model.id) },
                            onRemove: { onRemoveModel(row.model.id) }
                        )
                        if index < rows.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func rowsForCapability(
        _ capability: LocalAIModelCapability
    ) -> [ModelSettingsRowModel] {
        let recommendations = SuperDictateModelPolicy.recommendations(
            for: deviceClass,
            capability: capability
        )
        let recommendationByID = Dictionary(
            uniqueKeysWithValues: recommendations.map { ($0.model.id, $0) }
        )

        let catalog = LocalAIModelCatalog.models(capableOf: capability)
        return catalog.map { model in
            let runtime = modelStates.first { $0.model.id == model.id }
                ?? LocalModelRuntimeState(
                    model: model,
                    installState: model.requiresNetworkDownload ? .notInstalled : .ready,
                    localStorageBytes: model.requiresNetworkDownload ? nil : 0
                )
            return ModelSettingsRowModel(
                model: model,
                runtime: runtime,
                recommendation: recommendationByID[model.id]
            )
        }
        .sorted { lhs, rhs in
            let leftRank = lhs.recommendation?.rank ?? Int.max
            let rightRank = rhs.recommendation?.rank ?? Int.max
            if leftRank != rightRank { return leftRank < rightRank }
            if lhs.runtime.isUsable != rhs.runtime.isUsable { return lhs.runtime.isUsable }
            return lhs.model.displayName < rhs.model.displayName
        }
    }
}

private struct ModelSettingsRowModel {
    let model: LocalAIModelDescriptor
    let runtime: LocalModelRuntimeState
    let recommendation: SuperDictateModelRecommendation?
}

private struct ModelSettingsRow: View {
    let row: ModelSettingsRowModel
    let isSelected: Bool
    let onSelect: () -> Void
    let onInstall: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.compact) {
            HStack(alignment: .top, spacing: SuperDictateDesign.Spacing.component) {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.micro) {
                    HStack(spacing: SuperDictateDesign.Spacing.inline) {
                        Text(row.model.displayName)
                            .font(SuperDictateDesign.TypeStyle.interfaceMedium)
                        if row.recommendation?.recommended == true {
                            Text("Recommended")
                                .font(SuperDictateDesign.TypeStyle.captionMedium)
                                .foregroundStyle(SuperDictateDesign.ColorRole.actionPrimary)
                        }
                        if isSelected {
                            Label("Active", systemImage: "checkmark")
                                .font(SuperDictateDesign.TypeStyle.captionMedium)
                                .foregroundStyle(SuperDictateDesign.ColorRole.success)
                        }
                    }

                    if let reason = row.recommendation?.reason {
                        Text(reason)
                            .font(SuperDictateDesign.TypeStyle.caption)
                            .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
                    } else if !row.model.notes.isEmpty {
                        Text(row.model.notes)
                            .font(SuperDictateDesign.TypeStyle.caption)
                            .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
                    }
                }

                Spacer(minLength: SuperDictateDesign.Spacing.component)
                action
            }

            HStack(spacing: SuperDictateDesign.Spacing.component) {
                metadata("Status", stateLabel)
                if let bytes = row.runtime.localStorageBytes ?? row.model.approximateDiskBytes {
                    metadata("Size", formatModelBytes(bytes))
                }
                metadata("Privacy", "On-device")
            }

            Text(row.model.licenseSummary)
                .font(SuperDictateDesign.TypeStyle.caption)
                .foregroundStyle(SuperDictateDesign.ColorRole.textTertiary)
                .textSelection(.enabled)

            if row.runtime.installState == .downloading {
                ProgressView(value: row.runtime.downloadProgress)
                    .progressViewStyle(.linear)
            }

            if let error = row.runtime.lastErrorMessage, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(SuperDictateDesign.TypeStyle.caption)
                    .foregroundStyle(SuperDictateDesign.ColorRole.warning)
            }
        }
        .padding(.vertical, SuperDictateDesign.Spacing.component)
    }

    @ViewBuilder
    private var action: some View {
        switch row.runtime.installState {
        case .ready:
            if isSelected {
                Button("Remove", role: .destructive, action: onRemove)
                    .buttonStyle(.plain)
                    .foregroundStyle(SuperDictateDesign.ColorRole.destructive)
            } else {
                HStack(spacing: SuperDictateDesign.Spacing.inline) {
                    Button("Use", action: onSelect)
                    Button("Remove", role: .destructive, action: onRemove)
                        .buttonStyle(.plain)
                        .foregroundStyle(SuperDictateDesign.ColorRole.destructive)
                }
            }
        case .notInstalled, .failed:
            Button(row.runtime.installState == .failed ? "Retry" : "Download", action: onInstall)
        case .downloading:
            Text("Downloading")
                .font(SuperDictateDesign.TypeStyle.caption)
                .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
        case .disabledByPolicy:
            Text("Unavailable")
                .font(SuperDictateDesign.TypeStyle.caption)
                .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
        }
    }

    private func metadata(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(SuperDictateDesign.TypeStyle.caption)
                .foregroundStyle(SuperDictateDesign.ColorRole.textTertiary)
            Text(value)
                .font(SuperDictateDesign.TypeStyle.captionMedium)
                .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
        }
    }

    private var stateLabel: String {
        switch row.runtime.installState {
        case .notInstalled: return "Not installed"
        case .downloading: return "Downloading"
        case .ready: return "Installed"
        case .failed: return "Failed"
        case .disabledByPolicy: return "Unavailable"
        }
    }

    private var iconName: String {
        switch row.model.adapterKind {
        case .ruleBased: return "slider.horizontal.3"
        case .whisperCpp, .whisperKit: return "waveform"
        case .llamaCpp, .mlx: return "brain.head.profile"
        case .custom: return "shippingbox"
        }
    }

    private var iconColor: Color {
        if isSelected { return SuperDictateDesign.ColorRole.actionPrimary }
        switch row.runtime.installState {
        case .ready: return SuperDictateDesign.ColorRole.success
        case .failed: return SuperDictateDesign.ColorRole.warning
        case .notInstalled, .downloading, .disabledByPolicy:
            return SuperDictateDesign.ColorRole.textSecondary
        }
    }
}

private func formatModelBytes(_ bytes: Int64) -> String {
    let value = max(0, Double(bytes))
    if value >= 1_024 * 1_024 * 1_024 {
        return String(format: "%.1f GB", value / 1_024 / 1_024 / 1_024)
    }
    if value >= 1_024 * 1_024 {
        return String(format: "%.0f MB", value / 1_024 / 1_024)
    }
    if value >= 1_024 {
        return String(format: "%.0f KB", value / 1_024)
    }
    return "\(Int(value)) B"
}
