import Foundation

public enum SuperDictateWorkbenchTab: String, Codable, CaseIterable, Sendable {
    case recorder
    case processing
    case transcript
    case summary
    case actions
    case models
}

public enum SuperDictateWorkbenchStatus: String, Codable, CaseIterable, Sendable {
    case idle
    case recording
    case processing
    case ready
    case needsReview = "needs_review"
    case needsAttention = "needs_attention"
    case failed
}

public enum SuperDictateWorkbenchTone: String, Codable, CaseIterable, Sendable {
    case neutral
    case positive
    case accent
    case warning
    case danger
}

public struct SuperDictateWorkbenchBadge: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let tone: SuperDictateWorkbenchTone

    public init(
        id: String,
        label: String,
        tone: SuperDictateWorkbenchTone
    ) {
        self.id = id
        self.label = label
        self.tone = tone
    }
}

public struct SuperDictateWorkbenchMetric: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let value: String
    public let detail: String?
    public let tone: SuperDictateWorkbenchTone

    public init(
        id: String,
        label: String,
        value: String,
        detail: String? = nil,
        tone: SuperDictateWorkbenchTone = .neutral
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.detail = detail
        self.tone = tone
    }
}

public enum SuperDictateWorkbenchCommandRole: String, Codable, CaseIterable, Sendable {
    case primary
    case secondary
    case destructive
}

public struct SuperDictateWorkbenchCommand: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let targetTab: SuperDictateWorkbenchTab
    public let role: SuperDictateWorkbenchCommandRole
    public let isEnabled: Bool

    public init(
        id: String,
        title: String,
        targetTab: SuperDictateWorkbenchTab,
        role: SuperDictateWorkbenchCommandRole,
        isEnabled: Bool
    ) {
        self.id = id
        self.title = title
        self.targetTab = targetTab
        self.role = role
        self.isEnabled = isEnabled
    }
}

public enum LocalModelInstallState: String, Codable, CaseIterable, Sendable {
    case notInstalled = "not_installed"
    case downloading
    case ready
    case failed
    case disabledByPolicy = "disabled_by_policy"
}

public struct LocalModelRuntimeState: Identifiable, Codable, Equatable, Sendable {
    public var id: String { model.id }
    public var model: LocalAIModelDescriptor
    public var installState: LocalModelInstallState
    public var downloadProgress: Double
    public var localStorageBytes: Int64?
    public var lastErrorMessage: String?
    public var updatedAt: Date

    public init(
        model: LocalAIModelDescriptor,
        installState: LocalModelInstallState = .notInstalled,
        downloadProgress: Double = 0,
        localStorageBytes: Int64? = nil,
        lastErrorMessage: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.model = model
        self.installState = installState
        self.downloadProgress = min(1, max(0, downloadProgress))
        self.localStorageBytes = localStorageBytes
        self.lastErrorMessage = lastErrorMessage
        self.updatedAt = updatedAt
    }

    public var isUsable: Bool {
        installState == .ready
    }

    public func supports(_ capability: LocalAIModelCapability) -> Bool {
        model.capabilities.contains(capability)
    }
}

public struct SuperDictateWorkbenchState: Codable, Equatable, Sendable {
    public var manifest: LocalRecordingManifest?
    public var selectedTab: SuperDictateWorkbenchTab
    public var activeProcessingStage: LocalAIProcessingStage?
    public var transcript: LocalTranscript?
    public var summary: LocalRecordingSummary?
    public var insights: [ExtractedInsight]
    public var actionItems: [ActionItem]
    public var issues: [LocalProcessingIssue]
    public var modelStates: [LocalModelRuntimeState]
    public var recoveryState: ChunkRecoveryState?
    public var updatedAt: Date

    public init(
        manifest: LocalRecordingManifest? = nil,
        selectedTab: SuperDictateWorkbenchTab = .recorder,
        activeProcessingStage: LocalAIProcessingStage? = nil,
        transcript: LocalTranscript? = nil,
        summary: LocalRecordingSummary? = nil,
        insights: [ExtractedInsight] = [],
        actionItems: [ActionItem] = [],
        issues: [LocalProcessingIssue] = [],
        modelStates: [LocalModelRuntimeState] = SuperDictateWorkbenchState.defaultModelStates(),
        recoveryState: ChunkRecoveryState? = nil,
        updatedAt: Date = Date()
    ) {
        self.manifest = manifest
        self.selectedTab = selectedTab
        self.activeProcessingStage = activeProcessingStage
        self.transcript = transcript
        self.summary = summary
        self.insights = insights
        self.actionItems = actionItems
        self.issues = issues
        self.modelStates = modelStates
        self.recoveryState = recoveryState
        self.updatedAt = updatedAt
    }

    public var recordingID: UUID? {
        manifest?.id ?? transcript?.recordingID ?? summary?.recordingID
    }

    public var status: SuperDictateWorkbenchStatus {
        if !issues.isEmpty || recoveryState == .needsAttention {
            return .needsAttention
        }
        if manifest?.lastFailure != nil {
            return .failed
        }
        if activeProcessingStage != nil || manifest?.localState == .processing {
            return .processing
        }
        if manifest?.localState == .open || manifest?.localState == .finalizing {
            return .recording
        }
        if requiresReviewCount > 0 {
            return .needsReview
        }
        if transcript != nil || summary != nil {
            return .ready
        }
        return .idle
    }

    public var availableTabs: [SuperDictateWorkbenchTab] {
        var tabs: [SuperDictateWorkbenchTab] = [.recorder, .processing]
        if transcript != nil {
            tabs.append(.transcript)
        }
        if summary != nil {
            tabs.append(.summary)
        }
        if !insights.isEmpty || !actionItems.isEmpty {
            tabs.append(.actions)
        }
        tabs.append(.models)
        return tabs
    }

    public var requiresReviewCount: Int {
        let candidateInsights = insights.filter { insight in
            insight.reviewState == .candidate
        }.count
        let localActions = actionItems.filter { action in
            action.synchronizationState == .local
        }.count
        return candidateInsights + localActions
    }

    public var badges: [SuperDictateWorkbenchBadge] {
        var badges: [SuperDictateWorkbenchBadge] = []

        badges.append(
            SuperDictateWorkbenchBadge(
                id: "privacy",
                label: "Local-first",
                tone: .positive
            )
        )

        if manifest?.productPolicy.cloudProcessing == .prohibited {
            badges.append(
                SuperDictateWorkbenchBadge(
                    id: "cloud",
                    label: "Cloud blocked",
                    tone: .warning
                )
            )
        }

        if requiresReviewCount > 0 {
            badges.append(
                SuperDictateWorkbenchBadge(
                    id: "review",
                    label: "\(requiresReviewCount) need review",
                    tone: .accent
                )
            )
        }

        if !issues.isEmpty {
            badges.append(
                SuperDictateWorkbenchBadge(
                    id: "issues",
                    label: "\(issues.count) processing issue",
                    tone: .warning
                )
            )
        }

        return badges
    }

    public var headlineMetrics: [SuperDictateWorkbenchMetric] {
        [
            SuperDictateWorkbenchMetric(
                id: "chunks",
                label: "Chunks",
                value: "\(manifest?.chunks.count ?? 0)",
                tone: manifest?.hasDurableLocalSource == true ? .positive : .neutral
            ),
            SuperDictateWorkbenchMetric(
                id: "duration",
                label: "Audio",
                value: formattedDurationMilliseconds(
                    transcript?.durationMilliseconds
                        ?? manifest?.totalChunkDurationMilliseconds
                        ?? 0
                )
            ),
            SuperDictateWorkbenchMetric(
                id: "segments",
                label: "Transcript",
                value: "\(transcript?.segments.count ?? 0)",
                detail: transcript?.modelID
            ),
            SuperDictateWorkbenchMetric(
                id: "actions",
                label: "Actions",
                value: "\(actionItems.count)",
                tone: actionItems.isEmpty ? .neutral : .accent
            ),
            SuperDictateWorkbenchMetric(
                id: "models",
                label: "Ready models",
                value: "\(modelStates.filter(\.isUsable).count)",
                tone: hasReadyModel(capableOf: .transcription) ? .positive : .warning
            ),
        ]
    }

    public var primaryCommand: SuperDictateWorkbenchCommand {
        switch status {
        case .idle:
            return SuperDictateWorkbenchCommand(
                id: "record",
                title: "Record",
                targetTab: .recorder,
                role: .primary,
                isEnabled: hasReadyModel(capableOf: .transcription)
            )
        case .recording:
            return SuperDictateWorkbenchCommand(
                id: "stop",
                title: "Stop",
                targetTab: .recorder,
                role: .primary,
                isEnabled: true
            )
        case .processing:
            return SuperDictateWorkbenchCommand(
                id: "view-processing",
                title: "Processing",
                targetTab: .processing,
                role: .secondary,
                isEnabled: true
            )
        case .needsReview:
            return SuperDictateWorkbenchCommand(
                id: "review",
                title: "Review",
                targetTab: .actions,
                role: .primary,
                isEnabled: true
            )
        case .needsAttention, .failed:
            return SuperDictateWorkbenchCommand(
                id: "recover",
                title: "Recover",
                targetTab: .processing,
                role: .primary,
                isEnabled: true
            )
        case .ready:
            return SuperDictateWorkbenchCommand(
                id: "open-summary",
                title: "Summary",
                targetTab: summary == nil ? .transcript : .summary,
                role: .primary,
                isEnabled: true
            )
        }
    }

    public var processingProgress: Double {
        guard let activeProcessingStage else {
            return status == .ready || status == .needsReview ? 1 : 0
        }

        let stages: [LocalAIProcessingStage] = [
            .validatingSource,
            .transcribing,
            .structuring,
            .summarizing,
            .extractingActions,
            .completed,
        ]
        guard let index = stages.firstIndex(of: activeProcessingStage) else {
            return 0
        }
        return Double(index + 1) / Double(stages.count)
    }

    public func hasReadyModel(capableOf capability: LocalAIModelCapability) -> Bool {
        modelStates.contains { state in
            state.isUsable && state.supports(capability)
        }
    }

    public func bestModel(
        capableOf capability: LocalAIModelCapability
    ) -> LocalModelRuntimeState? {
        modelStates
            .filter { $0.supports(capability) }
            .sorted { lhs, rhs in
                if lhs.isUsable != rhs.isUsable {
                    return lhs.isUsable
                }
                return lhs.model.displayName < rhs.model.displayName
            }
            .first
    }

    public mutating func apply(
        _ result: LocalProcessingResult,
        at date: Date = Date()
    ) {
        transcript = result.transcript
        summary = result.summary
        insights = result.insights
        actionItems = result.actionItems
        issues = result.issues
        activeProcessingStage = nil
        selectedTab = result.summary == nil ? .transcript : .summary
        updatedAt = date
    }

    public static func defaultModelStates() -> [LocalModelRuntimeState] {
        ([LocalAIModelCatalog.builtInRuleBased] + LocalAIModelCatalog.recommendedLocalFirst)
            .map { model in
                LocalModelRuntimeState(
                    model: model,
                    installState: model.requiresNetworkDownload ? .notInstalled : .ready,
                    localStorageBytes: model.requiresNetworkDownload ? nil : 0
                )
            }
    }
}

private func formattedDurationMilliseconds(_ milliseconds: Int64) -> String {
    let totalSeconds = max(0, milliseconds / 1_000)
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%02lld:%02lld", minutes, seconds)
}
