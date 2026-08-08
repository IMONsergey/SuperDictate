import AppKit
import SwiftUI
import SuperDictateCore
import SuperDictateUI

/// Owns the visible native product window in the control-panel process.
///
/// The background agent remains the audio/hotkey/ASR engine. Product content is
/// backed by the private durable Library index; the legacy rolling history is
/// only an input for incremental migration until the agent writes the Library
/// directly on every successful dictation.
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
    private var lastRuntimeRecordingIDs: Set<UUID> = []
    private var pendingRuntimeRecordings: [SuperDictateRecording]?
    private var librarySyncTask: Task<Void, Never>?
    private var window: NSWindow?

    init(
        initialSnapshot: SuperDictateProductSnapshot,
        language: SuperDictateInterfaceLanguage,
        onOpenSettings: @escaping @MainActor () -> Void,
        onOpenSystemStatus: @escaping @MainActor () -> Void,
        onClose: @escaping @MainActor () -> Void
    ) {
        model = SuperDictateMainModel(snapshot: initialSnapshot, language: language)
        runtimeSnapshot = initialSnapshot
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
        scheduleLibrarySync(recordings: initialSnapshot.recordings, forceReload: true)
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        scheduleLibrarySync(recordings: runtimeSnapshot.recordings, forceReload: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refresh(snapshot: SuperDictateProductSnapshot,
                 language: SuperDictateInterfaceLanguage) {
        runtimeSnapshot = snapshot
        if model.language != language {
            model.language = language
        }
        applyCombinedSnapshot()
        scheduleLibrarySync(recordings: snapshot.recordings, forceReload: false)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === window else { return }
        librarySyncTask?.cancel()
        librarySyncTask = nil
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
        guard libraryLoaded else {
            if model.snapshot != runtimeSnapshot {
                model.snapshot = runtimeSnapshot
            }
            return
        }

        let combined = SuperDictateProductSnapshot(
            status: runtimeSnapshot.status,
            recordings: libraryArchive.recordings,
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

    private func scheduleLibrarySync(
        recordings: [SuperDictateRecording],
        forceReload: Bool
    ) {
        guard let libraryStore else { return }

        let recordingIDs = Set(recordings.map(\.id))
        guard forceReload || !libraryLoaded || recordingIDs != lastRuntimeRecordingIDs else {
            return
        }
        lastRuntimeRecordingIDs = recordingIDs
        pendingRuntimeRecordings = recordings

        guard librarySyncTask == nil else { return }
        librarySyncTask = Task { [weak self] in
            guard let self else { return }

            do {
                var archive = try await libraryStore.load()
                let runtimeRecordings = self.pendingRuntimeRecordings ?? []
                self.pendingRuntimeRecordings = nil

                var recordingIDs = Set(archive.recordings.map(\.id))
                var documentIDs = Set(archive.memoryDocuments.map(\.recordingID))
                var changed = false

                for recording in runtimeRecordings {
                    if recordingIDs.insert(recording.id).inserted {
                        archive.recordings.append(recording)
                        changed = true
                    }
                    if documentIDs.insert(recording.id).inserted {
                        archive.memoryDocuments.append(SuperDictateMemoryDocument(recording: recording))
                        changed = true
                    }
                }

                if changed {
                    try await libraryStore.save(archive)
                }

                self.libraryArchive = archive
                self.libraryLoaded = true
                self.applyCombinedSnapshot()
            } catch is CancellationError {
                self.librarySyncTask = nil
                return
            } catch {
                // Library is a rebuildable private index. A read/write failure
                // must never stop dictation or hide the runtime fallback state.
                log("product Library sync failed: \(error.localizedDescription)")
                self.libraryLoaded = false
                self.applyCombinedSnapshot()
            }

            let pending = self.pendingRuntimeRecordings
            self.librarySyncTask = nil
            if let pending {
                self.scheduleLibrarySync(recordings: pending, forceReload: true)
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
            // Navigation is local SwiftUI state; no runtime side effect required.
            break
        case .toggleTask:
            // Task mutation will become a durable Library operation once the
            // evidence-backed task review surface is connected.
            break
        }
    }
}
