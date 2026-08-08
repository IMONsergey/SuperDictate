from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one source match, found {count}")
    return text.replace(old, new, 1)


# 1. Make the visible product process a read-only Library consumer.
controller_path = Path("swift/Sources/Parakey/NativeProductWindowController.swift")
controller = controller_path.read_text()
required_controller_markers = [
    "final class NativeProductWindowController",
    "private let libraryStore: JSONSuperDictateLibraryStore?",
    "private func applyCombinedSnapshot()",
    "private func scheduleLibrarySync(",
]
for marker in required_controller_markers:
    if marker not in controller:
        raise SystemExit(f"unexpected product-window controller shape: missing {marker}")

controller_path.write_text(r'''import AppKit
import SwiftUI
import SuperDictateCore
import SuperDictateUI

/// Owns the visible native product window in the control-panel process.
///
/// The background agent is the only durable Library writer. This visible
/// process reads the atomically replaced archive and combines it with live
/// runtime health/status. It never performs a Library read-modify-write cycle.
@MainActor
final class NativeProductWindowController: NSObject, NSWindowDelegate {
    private let model: SuperDictateMainModel
    private let onOpenSettings: @MainActor () -> Void
    private let onOpenSystemStatus: @MainActor () -> Void
    private let onClose: @MainActor () -> Void
    private let libraryStore: JSONSuperDictateLibraryStore?

    private var runtimeSnapshot: SuperDictateProductSnapshot
    private var libraryArchive = SuperDictateLibraryArchive()
    private var libraryLoaded = false
    private var historyEnabled: Bool
    private var libraryReloadTask: Task<Void, Never>?
    private var window: NSWindow?

    init(
        initialSnapshot: SuperDictateProductSnapshot,
        language: SuperDictateInterfaceLanguage,
        historyEnabled: Bool = true,
        onOpenSettings: @escaping @MainActor () -> Void,
        onOpenSystemStatus: @escaping @MainActor () -> Void,
        onClose: @escaping @MainActor () -> Void
    ) {
        model = SuperDictateMainModel(snapshot: initialSnapshot, language: language)
        runtimeSnapshot = initialSnapshot
        self.historyEnabled = historyEnabled
        self.onOpenSettings = onOpenSettings
        self.onOpenSystemStatus = onOpenSystemStatus
        self.onClose = onClose

        do {
            let root = try superDictateApplicationSupportDirectory()
            libraryStore = try JSONSuperDictateLibraryStore(rootDirectory: root)
        } catch {
            libraryStore = nil
            log("product Library unavailable: \(error.localizedDescription)")
        }

        super.init()
        scheduleLibraryReload(force: true)
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        scheduleLibraryReload(force: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refresh(
        snapshot: SuperDictateProductSnapshot,
        language: SuperDictateInterfaceLanguage,
        historyEnabled: Bool = true
    ) {
        runtimeSnapshot = snapshot
        if model.language != language {
            model.language = language
        }

        if self.historyEnabled != historyEnabled {
            self.historyEnabled = historyEnabled
            if !historyEnabled {
                libraryLoaded = false
                libraryArchive = SuperDictateLibraryArchive()
                libraryReloadTask?.cancel()
                libraryReloadTask = nil
            }
        }

        applyCombinedSnapshot()
        scheduleLibraryReload(force: false)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === window else { return }
        libraryReloadTask?.cancel()
        libraryReloadTask = nil
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

    private func applyCombinedSnapshot() {
        guard historyEnabled else {
            let hiddenHistorySnapshot = SuperDictateProductSnapshot(
                status: runtimeSnapshot.status,
                recordings: [],
                tasks: [],
                activeRecordingStartedAt: runtimeSnapshot.activeRecordingStartedAt,
                issueMessage: runtimeSnapshot.issueMessage
            )
            if model.snapshot != hiddenHistorySnapshot {
                model.snapshot = hiddenHistorySnapshot
            }
            if !model.memoryDocuments.isEmpty {
                model.memoryDocuments = []
            }
            return
        }

        guard libraryLoaded else {
            if model.snapshot != runtimeSnapshot {
                model.snapshot = runtimeSnapshot
            }
            return
        }

        let liveByID = Dictionary(
            uniqueKeysWithValues: runtimeSnapshot.recordings.map { ($0.id, $0) }
        )
        let visibleRecordings = libraryArchive.recordings.map { durable in
            guard let live = liveByID[durable.id] else { return durable }
            return SuperDictateRecording(
                id: durable.id,
                title: durable.title,
                transcript: durable.transcript,
                summary: durable.summary,
                createdAt: durable.createdAt,
                durationSeconds: durable.durationSeconds,
                people: durable.people,
                requiresAttention: live.requiresAttention
            )
        }

        let combined = SuperDictateProductSnapshot(
            status: runtimeSnapshot.status,
            recordings: visibleRecordings,
            tasks: libraryArchive.tasks,
            activeRecordingStartedAt: runtimeSnapshot.activeRecordingStartedAt,
            issueMessage: runtimeSnapshot.issueMessage
        )
        if model.snapshot != combined {
            model.snapshot = combined
        }
        if model.memoryDocuments != libraryArchive.memoryDocuments {
            model.memoryDocuments = libraryArchive.memoryDocuments
        }
    }

    private func scheduleLibraryReload(force: Bool) {
        guard historyEnabled,
              let libraryStore,
              libraryReloadTask == nil else { return }

        let runtimeIDs = Set(runtimeSnapshot.recordings.map(\.id))
        let durableIDs = Set(libraryArchive.recordings.map(\.id))
        let agentHasUnindexedHistory = !runtimeIDs.isSubset(of: durableIDs)
        guard force || !libraryLoaded || agentHasUnindexedHistory else { return }

        libraryReloadTask = Task { [weak self] in
            guard let self else { return }
            defer { self.libraryReloadTask = nil }

            do {
                let archive = try await libraryStore.load()
                guard !Task.isCancelled else { return }
                self.libraryArchive = archive
                self.libraryLoaded = true
                self.applyCombinedSnapshot()
            } catch is CancellationError {
                return
            } catch {
                // The Library is secondary to live dictation. A read failure must
                // not hide the current runtime state or block capture.
                log("product Library read failed: \(error.localizedDescription)")
                self.libraryLoaded = false
                self.applyCombinedSnapshot()
            }
        }
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
            break
        case .toggleTask:
            // Durable task mutation will be wired once task review/storage is live.
            break
        }
    }
}
''')

# 2. Wire single-writer persistence and history privacy into the monolithic
# runtime through exact, narrow hooks only.
main_path = Path("swift/Sources/Parakey/main.swift")
text = main_path.read_text()

# Existing visible-window refresh calls: carry the explicit history privacy flag.
old_refresh = "productWindowController.refresh(snapshot: snapshot, language: productLanguage)"
new_refresh = "productWindowController.refresh(\n                snapshot: snapshot,\n                language: productLanguage,\n                historyEnabled: settings.recentTranscriptLimit != .off\n            )"
count = text.count(old_refresh)
if count not in (0, 1):
    raise SystemExit(f"show-window product refresh: expected 0/1 source match, found {count}")
if count == 1:
    text = text.replace(old_refresh, new_refresh, 1)

old_controller_init = """            initialSnapshot: snapshot,
            language: productLanguage,
            onOpenSettings:"""
new_controller_init = """            initialSnapshot: snapshot,
            language: productLanguage,
            historyEnabled: settings.recentTranscriptLimit != .off,
            onOpenSettings:"""
text = replace_once(
    text,
    old_controller_init,
    new_controller_init,
    "product controller init history flag",
)

old_periodic_refresh = """        productWindowController?.refresh(
            snapshot: makeSuperDictateProductSnapshot(
                settings: settings,
                agentState: agentState,
                agentRunning: agentRunning,
                language: language
            ),
            language: productLanguage
        )
"""
new_periodic_refresh = """        productWindowController?.refresh(
            snapshot: makeSuperDictateProductSnapshot(
                settings: settings,
                agentState: agentState,
                agentRunning: agentRunning,
                language: language
            ),
            language: productLanguage,
            historyEnabled: settings.recentTranscriptLimit != .off
        )
"""
text = replace_once(
    text,
    old_periodic_refresh,
    new_periodic_refresh,
    "periodic product refresh history flag",
)

# Successful history persistence -> background durable Library merge.
old_history_persist = """        history = next
        settings.recentTranscriptEntries = history
        if rebuildMenuAfterPersisting {
            rebuildMenu()
        }
"""
new_history_persist = """        history = next
        settings.recentTranscriptEntries = history
        persistCurrentHistoryToProductLibrary()
        if rebuildMenuAfterPersisting {
            rebuildMenu()
        }
"""
text = replace_once(
    text,
    old_history_persist,
    new_history_persist,
    "successful history Library persistence",
)

# Replace the existing recent-history-off helper so History=Off also clears the
# durable transcript Library even if the bounded runtime cache is already empty.
function_start = text.find("    private func applyRecentTranscriptLimit() {")
function_end = text.find("    /// 60-char preview", function_start)
if function_start < 0 or function_end < 0:
    raise SystemExit("applyRecentTranscriptLimit function boundaries not found")
existing_function = text[function_start:function_end]
if "ProductLibraryPersistence.scheduleClear()" not in existing_function:
    replacement_function = '''    private func applyRecentTranscriptLimit() {
        guard settings.recentTranscriptLimit == .off else { return }
        if !history.isEmpty {
            let removed = history.count
            history.removeAll()
            settings.recentTranscriptEntries = []
            log("recent transcript history disabled and cleared (\(removed) entries)")
        }
        ProductLibraryPersistence.scheduleClear()
    }

    private func persistCurrentHistoryToProductLibrary() {
        guard settings.recentTranscriptLimit != .off else { return }
        ProductLibraryPersistence.scheduleLegacyHistoryMerge(
            history.map {
                ProductLegacyHistoryValue(
                    text: $0.text,
                    transcriptionDurationSeconds: $0.transcriptionDurationSeconds
                )
            }
        )
    }

'''
    text = text[:function_start] + replacement_function + text[function_end:]

# Startup migration: after the launch path applies the legacy history limit,
# ensure existing installs are indexed without waiting for a new dictation.
launch_start = text.find("func applicationDidFinishLaunching")
launch_end = text.find("func applicationWillTerminate", launch_start)
if launch_start < 0 or launch_end < 0:
    raise SystemExit("application lifecycle boundaries not found")
launch_section = text[launch_start:launch_end]
startup_call = "        persistCurrentHistoryToProductLibrary()\n"
if startup_call not in launch_section:
    marker = "        applyRecentTranscriptLimit()\n"
    marker_count = launch_section.count(marker)
    if marker_count != 1:
        raise SystemExit(
            f"startup migration marker: expected exactly one applyRecentTranscriptLimit call, found {marker_count}"
        )
    launch_section = launch_section.replace(
        marker,
        marker + startup_call,
        1,
    )
    text = text[:launch_start] + launch_section + text[launch_end:]

main_path.write_text(text)
