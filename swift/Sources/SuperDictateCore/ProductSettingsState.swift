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

    public init(kind: SuperDictatePermissionKind, state: SuperDictatePermissionState) {
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

public enum SuperDictateSettingsUpdateState: Equatable, Sendable {
    case checking
    case current(version: String)
    case available(version: String)
    case failed(message: String)
}

/// User-facing projection of the existing runtime settings and service state.
///
/// This is deliberately not a second persistence model. The legacy/runtime
/// settings object remains authoritative while Settings v2 is migrated. This
/// snapshot contains only concepts the native Settings window is allowed to
/// display; diagnostic implementation details stay behind System Status.
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

    public var historyEnabled: Bool
    public var historyLimitDescription: String
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
        historyEnabled: Bool,
        historyLimitDescription: String,
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
        self.historyEnabled = historyEnabled
        self.historyLimitDescription = historyLimitDescription
        self.libraryRecordingCount = max(0, libraryRecordingCount)
        self.serviceState = serviceState
        self.permissions = permissions
        self.appVersion = appVersion
        self.updateState = updateState
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

public enum SuperDictateSettingsCommand: Equatable, Sendable {
    case editShortcuts
    case setRemoveFillerWords(Bool)
    case openModelManager
    case setHistoryEnabled(Bool)
    /// Explicit durable Library deletion. This is intentionally distinct from
    /// removing rows from the bounded recent-history cache.
    case clearLibraryHistory
    case openPermission(SuperDictatePermissionKind)
    case startService
    case restartService
    case stopService
    case checkForUpdates
    case installAvailableUpdate
    case openSystemStatus
}
