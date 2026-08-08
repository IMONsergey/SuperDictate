import Foundation
import SuperDictateCore

/// Stable inputs that remain owned by the visible control-panel runtime rather
/// than being guessed inside the Settings adapter.
struct ProductSettingsRuntimeInputs: Sendable {
    let libraryRecordingCount: Int
    let updateState: SuperDictateSettingsUpdateState
}

@MainActor
func makeSuperDictateSettingsSnapshot(
    settings: Settings,
    agentState: AgentRuntimeState?,
    agentRunning: Bool,
    inputs: ProductSettingsRuntimeInputs
) -> SuperDictateSettingsSnapshot {
    let missingPermissionNames = Set(agentState?.missingPermissions ?? [])
    let permissions: [SuperDictatePermissionStatus] = [
        permissionStatus(
            kind: .microphone,
            runtimeName: Permission.microphone.rawValue,
            missingPermissionNames: missingPermissionNames
        ),
        permissionStatus(
            kind: .accessibility,
            runtimeName: Permission.accessibility.rawValue,
            missingPermissionNames: missingPermissionNames
        ),
        permissionStatus(
            kind: .inputMonitoring,
            runtimeName: Permission.inputMonitoring.rawValue,
            missingPermissionNames: missingPermissionNames
        ),
    ]

    let profile = settings.speechModelProfile
    let historyLimit = settings.recentTranscriptLimit

    return SuperDictateSettingsSnapshot(
        primaryShortcut: settings.configuredHotkey.name,
        alternateShortcut: settings.alternateCompletionEnabled
            ? settings.configuredEnterHotkey.name
            : nil,
        historyShortcut: settings.configuredHistoryHotkey.name,
        triggerMode: TRIGGER_DISPLAY[settings.triggerMode] ?? settings.triggerMode.rawValue,
        completionBehavior: settings.primaryCompletionBehavior.rawValue,
        removeFillerWords: settings.removeFillerWords,
        speechModelName: profile.shortName,
        speechModelDetail: profile.aboutModelText,
        speechModelReady: agentState?.speechModelReady ?? false,
        historyEnabled: historyLimit != .off,
        historyLimitDescription: RECENT_TRANSCRIPT_LIMIT_DISPLAY[historyLimit] ?? historyLimit.rawValue,
        libraryRecordingCount: inputs.libraryRecordingCount,
        serviceState: productServiceState(agentState: agentState, agentRunning: agentRunning),
        permissions: permissions,
        appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—",
        updateState: inputs.updateState
    )
}

private func permissionStatus(
    kind: SuperDictatePermissionKind,
    runtimeName: String,
    missingPermissionNames: Set<String>
) -> SuperDictatePermissionStatus {
    SuperDictatePermissionStatus(
        kind: kind,
        state: missingPermissionNames.contains(runtimeName) ? .missing : .granted
    )
}

private func productServiceState(
    agentState: AgentRuntimeState?,
    agentRunning: Bool
) -> SuperDictateServiceState {
    guard agentRunning else { return .stopped }
    guard let agentState else { return .starting }

    switch agentState.status {
    case "ready", "recording", "transcribing":
        return .running
    case "starting":
        return .starting
    case "stopped":
        return .stopped
    case "error", "needs_permissions", "stopping":
        return .needsAttention
    default:
        return agentState.isReady ? .running : .starting
    }
}
