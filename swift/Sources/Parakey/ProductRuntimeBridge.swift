import AppKit
import Foundation
import SuperDictateCore

private let PRODUCT_CAPTURE_COMMAND_NOTIFICATION = Notification.Name("com.local.superdictate.product-capture-command")
private let PRODUCT_CAPTURE_COMMAND_KEY = "command"
private let PRODUCT_CAPTURE_SENDER_PID_KEY = "senderPID"

enum ProductCaptureCommand: String, Sendable {
    case start
    case stop
}

enum ProductCaptureCommandSender {
    static func send(_ command: ProductCaptureCommand) {
        DistributedNotificationCenter.default().postNotificationName(
            PRODUCT_CAPTURE_COMMAND_NOTIFICATION,
            object: nil,
            userInfo: [
                PRODUCT_CAPTURE_COMMAND_KEY: command.rawValue,
                PRODUCT_CAPTURE_SENDER_PID_KEY: NSNumber(value: getpid()),
            ],
            deliverImmediately: true
        )
    }
}

@MainActor
final class ProductCaptureCommandObserver: NSObject {
    private let onStart: @MainActor () -> Void
    private let onStop: @MainActor () -> Void

    init(
        onStart: @escaping @MainActor () -> Void,
        onStop: @escaping @MainActor () -> Void
    ) {
        self.onStart = onStart
        self.onStop = onStop
        super.init()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(receive(_:)),
            name: PRODUCT_CAPTURE_COMMAND_NOTIFICATION,
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(
            self,
            name: PRODUCT_CAPTURE_COMMAND_NOTIFICATION,
            object: nil
        )
    }

    @objc private func receive(_ notification: Notification) {
        guard let rawCommand = notification.userInfo?[PRODUCT_CAPTURE_COMMAND_KEY] as? String,
              let command = ProductCaptureCommand(rawValue: rawCommand),
              let senderPIDNumber = notification.userInfo?[PRODUCT_CAPTURE_SENDER_PID_KEY] as? NSNumber else {
            return
        }

        let senderPID = pid_t(senderPIDNumber.int32Value)
        guard trustedProductSender(pid: senderPID) else {
            log("product capture command rejected: untrusted sender")
            return
        }

        switch command {
        case .start:
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == senderPID else {
                log("product capture command rejected: start sender is not frontmost")
                return
            }
            onStart()
        case .stop:
            onStop()
        }
    }

    private func trustedProductSender(pid: pid_t) -> Bool {
        guard pid > 0,
              pid != getpid(),
              let sender = NSRunningApplication(processIdentifier: pid),
              sender.bundleIdentifier == Bundle.main.bundleIdentifier,
              let senderBundleURL = sender.bundleURL?.standardizedFileURL else {
            return false
        }
        return senderBundleURL == Bundle.main.bundleURL.standardizedFileURL
    }
}

@MainActor
func makeSuperDictateProductSnapshot(
    settings: Settings,
    agentState: AgentRuntimeState?,
    agentRunning: Bool,
    language: InterfaceLanguage
) -> SuperDictateProductSnapshot {
    // The same migration contract feeds both the volatile live projection and
    // the durable Library. New rows therefore keep one UUID/date/audio-duration
    // identity from their first visible frame through disk persistence; older
    // pre-metadata rows retain the deterministic legacy fallback identity.
    let recordings = SuperDictateLegacyHistoryMigrator.recordings(
        from: settings.recentTranscriptEntries.map {
            SuperDictateLegacyHistoryEntry(
                text: $0.text,
                transcriptionDurationSeconds: $0.transcriptionDurationSeconds,
                recordingID: $0.recordingID,
                createdAt: $0.createdAt,
                sourceAudioDurationSeconds: $0.sourceAudioDurationSeconds
            )
        }
    )

    let status: SuperDictateRuntimeStatus
    let issueMessage: String?
    if agentState?.status == "starting" {
        status = .starting
        issueMessage = nil
    } else if !agentRunning {
        status = .needsAttention
        issueMessage = localizedText(
            "Фоновая служба диктовки не запущена.",
            "The background dictation service is not running.",
            language: language
        )
    } else if agentState?.isRecording == true {
        status = .recording
        issueMessage = nil
    } else if agentState?.isTranscribing == true {
        status = .transcribing
        issueMessage = nil
    } else if let agentState,
              ["error", "needs_permissions", "stopped", "stopping"].contains(agentState.status) {
        status = .needsAttention
        let fallback = localizedText(
            "SuperDictate требует внимания.",
            "SuperDictate needs attention.",
            language: language
        )
        issueMessage = agentState.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? fallback
            : agentState.detail
    } else {
        status = recordings.isEmpty ? .idle : .ready
        issueMessage = nil
    }

    return SuperDictateProductSnapshot(
        status: status,
        recordings: recordings,
        tasks: [],
        activeRecordingStartedAt: nil,
        issueMessage: issueMessage
    )
}
