import AppKit
import SwiftUI
import SuperDictateCore
import SuperDictateUI

/// Owns the visible native product window in the control-panel process.
///
/// The background agent is the only durable Library writer. This controller is
/// deliberately read-only: it combines atomic Library snapshots with volatile
/// runtime state for presentation, but never saves, upserts or deletes Library
/// content itself.
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
    private var libraryReadTask: Task<Void, Never>?
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
        applyPresentationSnapshot()
        scheduleLibraryRead(forceReload: true)
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        scheduleLibraryRead(forceReload: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refresh(snapshot: SuperDictateProductSnapshot,
                 language: SuperDictateInterfaceLanguage) {
        runtimeSnapshot = snapshot
        if model.language != language {
            model.language = language
        }

        if !isTranscriptHistoryEnabled {
            // Privacy state changes must be reflected immediately in the UI;
            // do not wait for the agent's asynchronous disk clear to finish.
            libraryReadTask?.cancel()
            libraryReadTask = nil
            libraryArchive = SuperDictateLibraryArchive()
            libraryLoaded = false
        }

        applyPresentationSnapshot()
        scheduleLibraryRead(forceReload: false)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === window else { return }
        libraryReadTask?.cancel()
        libraryReadTask = nil
        window = nil
        onClose()
    }

    private var isTranscriptHistoryEnabled: Bool {
        Settings.shared.recentTranscriptLimit != .off
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

    private func applyPresentationSnapshot() {
        guard isTranscriptHistoryEnabled else {
            let hidden = SuperDictateProductSnapshot(
                status: runtimeSnapshot.status,
                recordings: [],
                tasks: [],
                activeRecordingStartedAt: runtimeSnapshot.activeRecordingStartedAt,
                issueMessage: runtimeSnapshot.issueMessage
            )
            if model.snapshot != hidden {
                model.snapshot = hidden
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
            let fallbackDocuments = runtimeSnapshot.recordings.map(
                SuperDictateMemoryDocument.init(recording:)
            )
            if model.memoryDocuments != fallbackDocuments {
                model.memoryDocuments = fallbackDocuments
            }
            return
        }

        // Reconciliation is presentation-only in this process. Its returned
        // archive may contain a just-finished live recording that the agent has
        // not written yet; we use that projection in memory but never persist it.
        let reconciled = SuperDictateLibraryReconciler.reconcile(
            archive: libraryArchive,
            liveSnapshot: runtimeSnapshot
        )
        if model.snapshot != reconciled.snapshot {
            model.snapshot = reconciled.snapshot
        }
        if model.memoryDocuments != reconciled.archive.memoryDocuments {
            model.memoryDocuments = reconciled.archive.memoryDocuments
        }
    }

    private func scheduleLibraryRead(forceReload: Bool) {
        guard isTranscriptHistoryEnabled,
              let libraryStore else { return }

        let liveIDs = Set(runtimeSnapshot.recordings.map(\.id))
        let durableIDs = Set(libraryArchive.recordings.map(\.id))
        let agentMayStillBePersisting = !liveIDs.isSubset(of: durableIDs)
        guard forceReload || !libraryLoaded || agentMayStillBePersisting else { return }
        guard libraryReadTask == nil else { return }

        libraryReadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let archive = try await libraryStore.load()
                guard !Task.isCancelled else {
                    self.libraryReadTask = nil
                    return
                }
                self.libraryArchive = archive
                self.libraryLoaded = true
                self.libraryReadTask = nil
                self.applyPresentationSnapshot()
            } catch is CancellationError {
                self.libraryReadTask = nil
            } catch {
                // Atomic Library read failure degrades to current live runtime
                // state. It must never interrupt capture/transcription.
                log("product Library read failed: \(error.localizedDescription)")
                self.libraryLoaded = false
                self.libraryReadTask = nil
                self.applyPresentationSnapshot()
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
            // Task mutation will become an agent-owned durable Library operation
            // when the evidence-backed task review surface is connected.
            break
        }
    }
}
