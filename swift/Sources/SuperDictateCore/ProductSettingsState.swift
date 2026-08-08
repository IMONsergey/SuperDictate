import Foundation

public enum SuperDictateSettingsSection: String, CaseIterable, Sendable, Identifiable {
    case dictation
    case models
    case privacy
    case system

    public var id: String { rawValue }
}

public enum SuperDictatePermissionKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case microphone
    case accessibility
    case inputMonitoring = "input_monitoring"

    public var id: String { rawValue }
}

public enum SuperDictatePermissionState: String, Codable, Sendable {
    case granted
    case missing
}

public struct SuperDictatePermissionStatus: Codable, Equatable, Sendable, Identifiable {
    public var kind: SuperDictatePermissionKind
    public var state: SuperDictatePermissionState

    public var id: String { kind.rawValue }

    public init(
        kind: SuperDictatePermissionKind,
        state: SuperDictatePermissionState
    ) {
        self.kind = kind
        self.state = state
    }
}

public enum SuperDictateServiceState: String, Codable, Sendable {
    case running
    case starting
    case stopped
    case needsAttention = "needs_attention"
}

/// User-facing updater state. Installation/preparation is distinct from an
/// update check so the UI never collapses a real in-progress install into a
/// misleading generic "Checking…" state.
public enum SuperDictateSettingsUpdateState: Equatable, Sendable {
    case checking
    case current(version: String)
    case available(version: String)
    case installing(version: String, phase: String)
    case failed(message: String)
}

/// Mirrors the current runtime `RecentTranscriptLimit` exactly.
///
/// Numeric values control only how many rows appear in the quick recent-history
/// surface. They are *not* durable retention caps: while history is enabled the
/// runtime may keep a larger local archive/Library. `.off` is the stronger
/// privacy state that disables transcript history and clears local transcript
/// memory through the agent-owned persistence path.
public enum SuperDictateRecentTranscriptMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case off
    case last1 = "1"
    case last5 = "5"
    case last10 = "10"

    public var id: String { rawValue }

    public var visibleEntryCount: Int {
        switch self {
        case .off: return 0
        case .last1: return 1
        case .last5: return 5
        case .last10: return 10
        }
    }
}

/// User-facing projection of the existing runtime settings and service state.
/// This is deliberately not a second persistence model.
public struct SuperDictateSettingsSnapshot: Equatable, Sendable {
    public var primaryShortcut: String
    public var alternateShortcut: String?
    public var historyShortcut: String?
    public var triggerMode: String
    public var completionBehavior: String
    public var removeFillerWords: Bool

    public var speechModelName: String
    public var speechModelDetail: String?
    public var speechModelReady: Bool

    public var recentTranscriptMode: SuperDictateRecentTranscriptMode
    public var libraryRecordingCount: Int

    public var serviceState: SuperDictateServiceState
    public var permissions: [SuperDictatePermissionStatus]
    public var appVersion: String
    public var updateState: SuperDictateSettingsUpdateState

    public init(
        primaryShortcut: String,
        alternateShortcut: String? = nil,
        historyShortcut: String? = nil,
        triggerMode: String,
        completionBehavior: String,
        removeFillerWords: Bool,
        speechModelName: String,
        speechModelDetail: String? = nil,
        speechModelReady: Bool,
        recentTranscriptMode: SuperDictateRecentTranscriptMode,
        libraryRecordingCount: Int,
        serviceState: SuperDictateServiceState,
        permissions: [SuperDictatePermissionStatus],
        appVersion: String,
        updateState: SuperDictateSettingsUpdateState
    ) {
        self.primaryShortcut = primaryShortcut
        self.alternateShortcut = Self.nonEmpty(alternateShortcut)
        self.historyShortcut = Self.nonEmpty(historyShortcut)
        self.triggerMode = triggerMode
        self.completionBehavior = completionBehavior
        self.removeFillerWords = removeFillerWords
        self.speechModelName = speechModelName
        self.speechModelDetail = Self.nonEmpty(speechModelDetail)
        self.speechModelReady = speechModelReady
        self.recentTranscriptMode = recentTranscriptMode
        self.libraryRecordingCount = max(0, libraryRecordingCount)
        self.serviceState = serviceState
        self.permissions = permissions
        self.appVersion = appVersion
        self.updateState = updateState
    }

    public var historyEnabled: Bool {
        recentTranscriptMode != .off
    }

    public var missingPermissions: [SuperDictatePermissionStatus] {
        permissions.filter { $0.state == .missing }
    }

    public var needsSystemAttention: Bool {
        serviceState == .needsAttention || !missingPermissions.isEmpty
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Only commands backed by an existing truthful capability belong here.
/// Models intentionally have no mutation command until the native model manager
/// is implemented and wired to the current runtime's tested switch/download path.
public enum SuperDictateSettingsCommand: Equatable, Sendable {
    case editShortcuts
    case setRemoveFillerWords(Bool)
    case setRecentTranscriptMode(SuperDictateRecentTranscriptMode)
    /// Explicit transcript-history deletion. The agent must clear both the
    /// bounded recent cache and the durable Library so a later migration cannot
    /// immediately recreate data the user explicitly removed.
    case clearTranscriptHistory
    case openPermission(SuperDictatePermissionKind)
    case startService
    case restartService
    case stopService
    case checkForUpdates
    case installAvailableUpdate
    case openSystemStatus
}
