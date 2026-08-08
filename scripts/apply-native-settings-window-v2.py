from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one source match, found {count}")
    return text.replace(old, new, 1)


# 1. Expose only a presentation count from the already read-only product window.
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

# 2. Add truthful updater installing/preparing state to Core and SwiftUI together.
state_path = Path("swift/Sources/SuperDictateCore/ProductSettingsState.swift")
state = state_path.read_text()
state = replace_once(
    state,
    """    case available(version: String)
    case failed(message: String)
""",
    """    case available(version: String)
    case installing(version: String, phase: String)
    case failed(message: String)
""",
    "Settings updater installing state",
)
state_path.write_text(state)

view_path = Path("swift/Sources/SuperDictateUI/SuperDictateSettingsView.swift")
view = view_path.read_text()
view = replace_once(
    view,
    """        case .available(let version):
            HStack {
                Text(text(\"Доступна версия \\(version)\", \"Version \\(version) is available\"))
                Spacer()
                Button(text(\"Установить\", \"Install\")) { onCommand(.installAvailableUpdate) }
            }
        case .failed(let message):
""",
    """        case .available(let version):
            HStack {
                Text(text(\"Доступна версия \\(version)\", \"Version \\(version) is available\"))
                Spacer()
                Button(text(\"Установить\", \"Install\")) { onCommand(.installAvailableUpdate) }
            }
        case .installing(let version, let phase):
            HStack(alignment: .top, spacing: SuperDictateDesign.Spacing.component) {
                ProgressView().controlSize(.small)
                VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.micro) {
                    Text(text(\"Обновляю до \\(version)…\", \"Updating to \\(version)…\"))
                    Text(phase)
                        .font(SuperDictateDesign.TypeStyle.caption)
                        .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
                }
            }
        case .failed(let message):
""",
    "Settings installing row",
)
# Models are truthful read-only until a real model-manager command handler lands.
view = replace_once(
    view,
    """            Button(text(\"Управление моделями…\", \"Manage models…\")) {
                onCommand(.openModelManager)
            }
""",
    """            Text(text(\"Выбор модели будет перенесён сюда отдельным шагом.\",
                      \"Model selection will move here in a dedicated step.\"))
                .font(SuperDictateDesign.TypeStyle.caption)
                .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
""",
    "remove fake model-manager action",
)
view_path.write_text(view)

# 3. Wire the native window into the existing control-panel runtime.
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
    "main window opens native Settings",
)
main = replace_once(
    main,
    """            language: productLanguage
        )

        let fingerprint = renderFingerprint()
""",
    """            language: productLanguage
        )
        refreshNativeSettingsWindow(agentState: agentState, agentRunning: agentRunning)

        let fingerprint = renderFingerprint()
""",
    "refresh native Settings with runtime state",
)

settings_methods_marker = """    private func showSystemStatusWindow() {
"""
settings_methods = """    private func nativeSettingsUpdateState() -> SuperDictateSettingsUpdateState {
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
            nativeSettingsWindowController.refresh(snapshot: snapshot, language: productLanguage)
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
        case .editShortcuts, .openModelManager:
            // Transitional drill-down: keep the tested legacy editor available
            // until these controls have native parity.
            openSettingsClicked(NSButton())

        case .setRemoveFillerWords(let enabled):
            ProductSettingsCommandSender.send(.setRemoveFillerWords(enabled))

        case .setRecentTranscriptMode(let mode):
            ProductSettingsCommandSender.send(.setRecentTranscriptMode(mode))

        case .clearTranscriptHistory:
            ProductSettingsCommandSender.send(.clearTranscriptHistory)

        case .openPermission(let kind):
            switch kind {
            case .microphone: Permissions.request(.microphone)
            case .accessibility: Permissions.request(.accessibility)
            case .inputMonitoring: Permissions.request(.inputMonitoring)
            }

        case .startService:
            settings.agentEnabled = true
            beginServiceOperation(.starting)

        case .restartService:
            settings.agentEnabled = true
            beginServiceOperation(.restarting)

        case .stopService:
            // Native Settings does not expose destructive service stop yet.
            showSystemStatusWindow()

        case .checkForUpdates:
            checkForUpdates()

        case .installAvailableUpdate:
            updateButtonClicked(NSButton())

        case .openSystemStatus:
            showSystemStatusWindow()
        }
    }

""" + settings_methods_marker
main = replace_once(main, settings_methods_marker, settings_methods, "native Settings methods")
main_path.write_text(main)
