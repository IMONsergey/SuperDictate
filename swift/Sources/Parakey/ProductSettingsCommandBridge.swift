import AppKit
import Foundation
import SuperDictateCore

private let PRODUCT_SETTINGS_COMMAND_NOTIFICATION = Notification.Name(
    "com.local.superdictate.product-settings-command"
)
private let PRODUCT_SETTINGS_COMMAND_KEY = "command"
private let PRODUCT_SETTINGS_VALUE_KEY = "value"
private let PRODUCT_SETTINGS_SENDER_PID_KEY = "senderPID"

enum ProductAgentSettingsCommand: Equatable, Sendable {
    case setRemoveFillerWords(Bool)
    case setRecentTranscriptMode(SuperDictateRecentTranscriptMode)
    case clearTranscriptHistory
}

enum ProductSettingsCommandSender {
    static func send(_ command: ProductAgentSettingsCommand) {
        var userInfo: [String: Any] = [
            PRODUCT_SETTINGS_SENDER_PID_KEY: NSNumber(value: getpid()),
        ]
        switch command {
        case .setRemoveFillerWords(let enabled):
            userInfo[PRODUCT_SETTINGS_COMMAND_KEY] = "set_remove_filler_words"
            userInfo[PRODUCT_SETTINGS_VALUE_KEY] = NSNumber(value: enabled)
        case .setRecentTranscriptMode(let mode):
            userInfo[PRODUCT_SETTINGS_COMMAND_KEY] = "set_recent_transcript_mode"
            userInfo[PRODUCT_SETTINGS_VALUE_KEY] = mode.rawValue
        case .clearTranscriptHistory:
            userInfo[PRODUCT_SETTINGS_COMMAND_KEY] = "clear_transcript_history"
        }
        DistributedNotificationCenter.default().postNotificationName(
            PRODUCT_SETTINGS_COMMAND_NOTIFICATION,
            object: nil,
            userInfo: userInfo,
            deliverImmediately: true
        )
    }
}

@MainActor
final class ProductSettingsCommandObserver: NSObject {
    private let onCommand: @MainActor (ProductAgentSettingsCommand) -> Void

    init(onCommand: @escaping @MainActor (ProductAgentSettingsCommand) -> Void) {
        self.onCommand = onCommand
        super.init()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(receive(_:)),
            name: PRODUCT_SETTINGS_COMMAND_NOTIFICATION,
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(
            self,
            name: PRODUCT_SETTINGS_COMMAND_NOTIFICATION,
            object: nil
        )
    }

    @objc private func receive(_ notification: Notification) {
        guard let senderPIDNumber = notification.userInfo?[PRODUCT_SETTINGS_SENDER_PID_KEY] as? NSNumber else {
            return
        }
        let senderPID = pid_t(senderPIDNumber.int32Value)
        guard trustedVisibleProductSender(pid: senderPID) else {
            log("product settings command rejected: untrusted sender")
            return
        }
        guard let command = decode(notification.userInfo ?? [:]) else {
            log("product settings command rejected: malformed payload")
            return
        }
        onCommand(command)
    }

    private func decode(_ userInfo: [AnyHashable: Any]) -> ProductAgentSettingsCommand? {
        guard let raw = userInfo[PRODUCT_SETTINGS_COMMAND_KEY] as? String else {
            return nil
        }
        switch raw {
        case "set_remove_filler_words":
            guard let value = userInfo[PRODUCT_SETTINGS_VALUE_KEY] as? NSNumber else {
                return nil
            }
            return .setRemoveFillerWords(value.boolValue)
        case "set_recent_transcript_mode":
            guard let value = userInfo[PRODUCT_SETTINGS_VALUE_KEY] as? String,
                  let mode = SuperDictateRecentTranscriptMode(rawValue: value) else {
                return nil
            }
            return .setRecentTranscriptMode(mode)
        case "clear_transcript_history":
            return .clearTranscriptHistory
        default:
            return nil
        }
    }

    private func trustedVisibleProductSender(pid: pid_t) -> Bool {
        guard pid > 0,
              pid != getpid(),
              NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
              let sender = NSRunningApplication(processIdentifier: pid),
              sender.bundleIdentifier == Bundle.main.bundleIdentifier,
              let senderBundleURL = sender.bundleURL?.standardizedFileURL else {
            return false
        }
        return senderBundleURL == Bundle.main.bundleURL.standardizedFileURL
    }
}
