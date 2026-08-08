from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one source match, found {count}")
    return text.replace(old, new, 1)


# 1. Expose only a presentation metric from the already read-only product
# controller. Settings never receives the Library store or filesystem URL.
product_path = Path("swift/Sources/Parakey/NativeProductWindowController.swift")
product = product_path.read_text()
product = replace_once(
    product,
    """    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
""",
    """    func close() {
        window?.close()
    }

    var libraryRecordingCount: Int {
        model.snapshot.recordings.count
    }

    func windowWillClose(_ notification: Notification) {
""",
    "product window Library count",
)
product_path.write_text(product)

# 2. Wire one stable native Settings window into the visible control-panel
# runtime. Existing service/updater/TCC handlers remain authoritative.
main_path = Path("swift/Sources/Parakey/main.swift")
main = main_path.read_text()

main = replace_once(
    main,
    """    private var hotkeyRecorder: HotkeyRecorderController?
    private var productWindowController: NativeProductWindowController?

    private var language: InterfaceLanguage { settings.interfaceLanguage }
""",
    """    private var hotkeyRecorder: HotkeyRecorderController?
    private var productWindowController: NativeProductWindowController?
    private var nativeSettingsWindowController: NativeSettingsWindowController?

    private var language: InterfaceLanguage { settings.interfaceLanguage }
""",
    "control panel native Settings property",
)

main = replace_once(
    main,
    """        updateTask?.cancel()
        updateTask = nil
        productWindowController = nil
        SuperDictateControlPanelRegistry.clearCurrentPanel()
""",
    """        updateTask?.cancel()
        updateTask = nil
        nativeSettingsWindowController = nil
        productWindowController = nil
        SuperDictateControlPanelRegistry.clearCurrentPanel()
""",
    "release native Settings on termination",
)

main = replace_once(
    main,
    """            language: productLanguage,
            onOpenSettings: { [weak self] in
                self?.openSettingsClicked(NSButton())
            },
""",
    """            language: productLanguage,
            onOpenSettings: { [weak self] in
                self?.showNativeSettingsWindow()
            },
""",
    "main product window opens native Settings",
)

main = replace_once(
    main,
    """            language: productLanguage
        )

        let fingerprint = renderFingerprint()
""",
    """            language: productLanguage
        )
        refreshNativeSettingsWindow(
            agentState: agentState,
            agentRunning: agentRunning
        )

        let fingerprint = renderFingerprint()
""",
    "refresh native Settings with runtime state",
)

marker = """    private func showSystemStatusWindow() {
"""
methods = """    private func nativeSettingsUpdateState() -> SuperDictateSettingsUpdateState {
        switch updateState {
        case .checking:
            return .checking
        case .upToDate(let version):
            return .current(version: version)
        case .available(let release):
            return .available(version: release.version)
        case .preparing(let version, let phase):
            return .installing(version: version, phase: phase)
        case .failed(let message):
            return .failed(message: message)
        }
    }

    private func nativeSettingsSnapshot(
        agentState: AgentRuntimeState?,
        agentRunning: Bool
    ) -> SuperDictateSettingsSnapshot {
        makeSuperDictateSettingsSnapshot(
            settings: settings,
            agentState: agentState,
            agentRunning: agentRunning,
            inputs: ProductSettingsRuntimeInputs(
                libraryRecordingCount: productWindowController?.libraryRecordingCount ?? 0,
                updateState: nativeSettingsUpdateState()
            )
        )
    }

    private func showNativeSettingsWindow() {
        let agentState = AgentRuntimeStateStore.read()
        let agentRunning = SuperDictateAgentService.isAgentRunning()
        let snapshot = nativeSettingsSnapshot(
            agentState: agentState,
            agentRunning: agentRunning
        )

        if let nativeSettingsWindowController {
            nativeSettingsWindowController.refresh(
                snapshot: snapshot,
                language: productLanguage
            )
            nativeSettingsWindowController.show()
            return
        }

        let controller = NativeSettingsWindowController(
            initialSnapshot: snapshot,
            language: productLanguage,
            onCommand: { [weak self] command in
                self?.handleNativeSettingsCommand(command)
            },
            onClose: { [weak self] in
                self?.nativeSettingsWindowController = nil
            }
        )
        nativeSettingsWindowController = controller
        controller.show()
    }

    private func refreshNativeSettingsWindow(
        agentState: AgentRuntimeState?,
        agentRunning: Bool
    ) {
        guard let nativeSettingsWindowController else { return }
        nativeSettingsWindowController.refresh(
            snapshot: nativeSettingsSnapshot(
                agentState: agentState,
                agentRunning: agentRunning
            ),
            language: productLanguage
        )
    }

    private func handleNativeSettingsCommand(_ command: SuperDictateSettingsCommand) {
        switch command {
        case .editShortcuts:
            // Keep the mature existing shortcut editor until native parity is
            // implemented. This is a real drill-down, not a fake native control.
            openSettingsClicked(NSButton())

        case .setRemoveFillerWords(let enabled):
            ProductSettingsCommandSender.send(.setRemoveFillerWords(enabled))

        case .setRecentTranscriptMode(let mode):
            ProductSettingsCommandSender.send(.setRecentTranscriptMode(mode))

        case .clearTranscriptHistory:
            ProductSettingsCommandSender.send(.clearTranscriptHistory)

        case .openPermission(let kind):
            switch kind {
            case .microphone:
                Permissions.request(.microphone)
            case .accessibility:
                Permissions.request(.accessibility)
            case .inputMonitoring:
                Permissions.request(.inputMonitoring)
            }

        case .startService:
            settings.agentEnabled = true
            beginServiceOperation(.starting)

        case .restartService:
            settings.agentEnabled = true
            beginServiceOperation(.restarting)

        case .stopService:
            // Deliberately not exposed in native Settings yet; preserve the
            // mature System Status surface for destructive service controls.
            showSystemStatusWindow()

        case .checkForUpdates:
            checkForUpdates()

        case .installAvailableUpdate:
            updateButtonClicked(NSButton())

        case .openSystemStatus:
            showSystemStatusWindow()
        }
    }

""" + marker
main = replace_once(
    main,
    marker,
    methods,
    "native Settings methods",
)

main_path.write_text(main)

final_product = product_path.read_text()
final_main = main_path.read_text()
assert "var libraryRecordingCount: Int" in final_product
assert "nativeSettingsWindowController: NativeSettingsWindowController?" in final_main
assert "case .preparing(let version, let phase):" in final_main
assert "return .installing(version: version, phase: phase)" in final_main
assert "ProductSettingsCommandSender.send(.clearTranscriptHistory)" in final_main
assert ".openModelManager" not in final_main
