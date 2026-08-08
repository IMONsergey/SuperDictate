import AppKit
import CryptoKit
import Foundation
import SuperDictateCore

private let PRODUCT_CAPTURE_COMMAND_NOTIFICATION = Notification.Name("com.local.superdictate.product-capture-command")
private let PRODUCT_CAPTURE_COMMAND_KEY = "command"
private let PRODUCT_CAPTURE_SENDER_PID_KEY = "senderPID"

/// Narrow command vocabulary between the visible control-panel process and the
/// background agent. Keep this deliberately smaller than the product command
/// enum: UI-only navigation/settings never need to cross the process boundary.
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

/// Receives capture commands inside the background agent.
///
/// A start request is accepted only when it comes from another process running
/// the exact same installed app bundle and that process is currently frontmost.
/// This prevents a generic distributed notification from becoming a stealth
/// recording API. Stop remains available to the same trusted bundle even if
/// focus changes between the click and delivery.
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
        let ownBundleURL = Bundle.main.bundleURL.standardizedFileURL
        return senderBundleURL == ownBundleURL
    }
}

/// Converts legacy recent-history data into the new product-facing state without
/// inventing metadata that the v0.2.37 archive does not contain.
@MainActor
func makeSuperDictateProductSnapshot(
    settings: Settings,
    agentState: AgentRuntimeState?,
    agentRunning: Bool,
    language: InterfaceLanguage
) -> SuperDictateProductSnapshot {
    let entries = settings.recentTranscriptEntries
    var occurrences: [String: Int] = [:]
    let recordings = entries.compactMap { entry -> SuperDictateRecording? in
        let text = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let occurrence = occurrences[text, default: 0]
        occurrences[text] = occurrence + 1
        return SuperDictateRecording(
            id: stableProductRecordingID(text: text, occurrence: occurrence),
            title: productRecordingTitle(text: text, language: language),
            transcript: text,
            summary: nil,
            createdAt: nil,
            durationSeconds: nil,
            people: [],
            requiresAttention: false
        )
    }

    let status: SuperDictateRuntimeStatus
    let issueMessage: String?
    if !agentRunning {
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
              agentState.status == "error" || agentState.status == "needs_permissions" || agentState.status == "stopped" {
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

private func productRecordingTitle(text: String, language: InterfaceLanguage) -> String {
    let flat = text
        .split(whereSeparator: { $0.isWhitespace })
        .joined(separator: " ")
    guard !flat.isEmpty else {
        return localizedText("Без названия", "Untitled", language: language)
    }
    if flat.count <= 68 { return flat }
    return String(flat.prefix(67)) + "…"
}

private func stableProductRecordingID(text: String, occurrence: Int) -> UUID {
    var hasher = SHA256()
    hasher.update(data: Data("superdictate-history-v1\u{0}\(occurrence)\u{0}\(text)".utf8))
    let bytes = Array(hasher.finalize().prefix(16))
    guard bytes.count == 16 else { return UUID() }
    return UUID(uuid: (
        bytes[0], bytes[1], bytes[2], bytes[3],
        bytes[4], bytes[5], bytes[6], bytes[7],
        bytes[8], bytes[9], bytes[10], bytes[11],
        bytes[12], bytes[13], bytes[14], bytes[15]
    ))
}
