import AppKit
import SwiftUI
import SuperDictateCore
import SuperDictateUI

/// Owns the visible native product window in the control-panel process.
///
/// The background agent remains the audio/hotkey/ASR engine. This controller
/// only renders product state and sends narrow commands through the trusted
/// bridge. The legacy compact panel remains available as System Status during
/// migration of service/permissions/update controls into Settings v2.
@MainActor
final class NativeProductWindowController: NSObject, NSWindowDelegate {
    private let model: SuperDictateMainModel
    private let onOpenSettings: @MainActor () -> Void
    private let onOpenSystemStatus: @MainActor () -> Void
    private let onClose: @MainActor () -> Void
    private var window: NSWindow?

    init(
        initialSnapshot: SuperDictateProductSnapshot,
        language: SuperDictateInterfaceLanguage,
        onOpenSettings: @escaping @MainActor () -> Void,
        onOpenSystemStatus: @escaping @MainActor () -> Void,
        onClose: @escaping @MainActor () -> Void
    ) {
        model = SuperDictateMainModel(snapshot: initialSnapshot, language: language)
        self.onOpenSettings = onOpenSettings
        self.onOpenSystemStatus = onOpenSystemStatus
        self.onClose = onClose
        super.init()
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refresh(snapshot: SuperDictateProductSnapshot,
                 language: SuperDictateInterfaceLanguage) {
        if model.snapshot != snapshot {
            model.snapshot = snapshot
        }
        if model.language != language {
            model.language = language
        }
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === window else { return }
        window = nil
        onClose()
    }

    private func makeWindow() -> NSWindow {
        let rootView = SuperDictateLiveMainView(model: model) { [weak self] command in
            self?.handle(command)
        }
        let host = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "SuperDictate"
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 840, height: 600)
        window.contentViewController = host
        window.delegate = self
        window.center()
        return window
    }

    private func handle(_ command: SuperDictateCommand) {
        switch command {
        case .startRecording:
            ProductCaptureCommandSender.send(.start)
        case .stopRecording:
            ProductCaptureCommandSender.send(.stop)
        case .copyTranscript(let recordingID):
            guard let recording = model.snapshot.recordings.first(where: { $0.id == recordingID }) else {
                return
            }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(recording.transcript, forType: .string)
        case .openSettings:
            onOpenSettings()
        case .openSystemStatus, .retryAttentionItem:
            onOpenSystemStatus()
        case .openRecording:
            // Navigation is local SwiftUI state; no runtime side effect required.
            break
        case .toggleTask:
            // Tasks are intentionally absent until evidence-backed task storage exists.
            break
        }
    }
}
