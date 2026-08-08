import AppKit
import SwiftUI
import SuperDictateCore
import SuperDictateUI

/// Owns the native Settings v2 window while the existing control-panel runtime
/// remains authoritative for state and mutations.
///
/// The controller never reads/writes Settings, service state, updater state or
/// TCC directly. Runtime code supplies a projection snapshot and receives typed
/// commands through one closure. This keeps the SwiftUI surface replaceable and
/// prevents a second persistence/control implementation from growing in UI code.
@MainActor
final class NativeSettingsWindowController: NSObject, NSWindowDelegate {
    private let model: SuperDictateSettingsModel
    private let onCommand: @MainActor (SuperDictateSettingsCommand) -> Void
    private let onClose: @MainActor () -> Void
    private var window: NSWindow?

    init(
        initialSnapshot: SuperDictateSettingsSnapshot,
        language: SuperDictateInterfaceLanguage,
        onCommand: @escaping @MainActor (SuperDictateSettingsCommand) -> Void,
        onClose: @escaping @MainActor () -> Void = {}
    ) {
        model = SuperDictateSettingsModel(
            snapshot: initialSnapshot,
            language: language
        )
        self.onCommand = onCommand
        self.onClose = onClose
        super.init()
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refresh(
        snapshot: SuperDictateSettingsSnapshot,
        language: SuperDictateInterfaceLanguage
    ) {
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
              closingWindow === window else {
            return
        }
        window = nil
        onClose()
    }

    private func makeWindow() -> NSWindow {
        let rootView = SuperDictateLiveSettingsView(model: model) { [weak self] command in
            self?.onCommand(command)
        }
        let host = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "SuperDictate Settings"
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 760, height: 520)
        window.contentViewController = host
        window.delegate = self
        window.center()
        return window
    }
}
