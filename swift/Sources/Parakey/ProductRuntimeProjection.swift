import Foundation
import SuperDictateCore

/// Read-side bridge from the legacy Parakey runtime into the clean product model.
///
/// This deliberately uses only existing internal runtime APIs that are already
/// safe to read across source files. It does not reach into `ParakeyApp` private
/// fields, synthesize hotkeys, or mutate capture state. The eventual window seam
/// can consume this projection while command routing remains explicit inside
/// `ParakeyApp`.
enum SuperDictateRuntimeProjection {
    static func snapshot(
        settings: Settings = .shared,
        agentState: AgentRuntimeState? = AgentRuntimeStateStore.read()
    ) -> SuperDictateProductSnapshot {
        let legacyEntries = settings.recentTranscriptEntries.map { entry in
            SuperDictateLegacyHistoryEntry(
                text: entry.text,
                transcriptionDurationSeconds: entry.transcriptionDurationSeconds
            )
        }
        let recordings = SuperDictateLegacyHistoryMigrator.recordings(
            from: legacyEntries
        )

        return SuperDictateProductSnapshot(
            status: productStatus(from: agentState, hasHistory: !recordings.isEmpty),
            recordings: recordings,
            tasks: [],
            activeRecordingStartedAt: nil,
            issueMessage: issueMessage(from: agentState)
        )
    }

    static func archive(
        settings: Settings = .shared
    ) -> SuperDictateLibraryArchive {
        let entries = settings.recentTranscriptEntries.map { entry in
            SuperDictateLegacyHistoryEntry(
                text: entry.text,
                transcriptionDurationSeconds: entry.transcriptionDurationSeconds
            )
        }
        return SuperDictateLegacyHistoryMigrator.archive(from: entries)
    }

    private static func productStatus(
        from state: AgentRuntimeState?,
        hasHistory: Bool
    ) -> SuperDictateRuntimeStatus {
        guard let state else {
            return hasHistory ? .ready : .idle
        }

        if state.isRecording {
            return .recording
        }
        if state.isTranscribing {
            return .transcribing
        }
        if !state.missingPermissions.isEmpty || state.status == "failed" || state.status == "error" {
            return .needsAttention
        }
        if state.isReady || hasHistory {
            return .ready
        }
        return .idle
    }

    private static func issueMessage(
        from state: AgentRuntimeState?
    ) -> String? {
        guard let state else { return nil }

        if !state.missingPermissions.isEmpty {
            return "SuperDictate needs permission: "
                + state.missingPermissions.joined(separator: ", ")
        }

        let detail = state.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !detail.isEmpty,
              state.status == "failed" || state.status == "error" else {
            return nil
        }
        return detail
    }
}
