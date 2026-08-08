from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one source match, found {count}")
    return text.replace(old, new, 1)


path = Path("swift/Sources/Parakey/main.swift")
text = path.read_text()

text = replace_once(
    text,
    """    private var hotkeyRecorder: HotkeyRecorderController?
    private var productCaptureCommandObserver: ProductCaptureCommandObserver?
    private var shouldResumeRuntimeAfterWake = false
""",
    """    private var hotkeyRecorder: HotkeyRecorderController?
    private var productCaptureCommandObserver: ProductCaptureCommandObserver?
    private var productSettingsCommandObserver: ProductSettingsCommandObserver?
    private var shouldResumeRuntimeAfterWake = false
""",
    "settings observer property",
)

text = replace_once(
    text,
    """        productCaptureCommandObserver = ProductCaptureCommandObserver(
            onStart: { [weak self] in self?.handlePress() },
            onStop: { [weak self] in self?.handleRelease() }
        )

        // Configure hotkey listener up front so it picks up the user's
""",
    """        productCaptureCommandObserver = ProductCaptureCommandObserver(
            onStart: { [weak self] in self?.handlePress() },
            onStop: { [weak self] in self?.handleRelease() }
        )
        productSettingsCommandObserver = ProductSettingsCommandObserver { [weak self] command in
            self?.handleProductSettingsCommand(command)
        }

        // Configure hotkey listener up front so it picks up the user's
""",
    "install settings command observer",
)

text = replace_once(
    text,
    """        removeHotkeyCaptureObservers()
        productCaptureCommandObserver = nil
        correctionSyncTimer?.invalidate()
""",
    """        removeHotkeyCaptureObservers()
        productCaptureCommandObserver = nil
        productSettingsCommandObserver = nil
        correctionSyncTimer?.invalidate()
""",
    "remove settings command observer",
)

marker = """    private func applyRecentTranscriptLimit() {
        guard settings.recentTranscriptLimit == .off else { return }
        let removed = history.count
        history.removeAll()
        settings.recentTranscriptEntries = []
        ProductLibraryPersistence.scheduleClear()
        log(\"recent transcript history disabled and Library clear scheduled (\\(removed) cached entries)\")
    }

"""
handler = marker + """    private func handleProductSettingsCommand(_ command: ProductAgentSettingsCommand) {
        switch command {
        case .setRemoveFillerWords(let enabled):
            settings.removeFillerWords = enabled
            log(\"remove filler words changed from product Settings: \\(enabled)\")

        case .setRecentTranscriptMode(let mode):
            settings.recentTranscriptLimit = runtimeRecentTranscriptLimit(mode)
            applyRecentTranscriptLimit()
            log(\"recent transcript mode changed from product Settings: \\(mode.rawValue)\")

        case .clearTranscriptHistory:
            let removed = history.count
            history.removeAll()
            settings.recentTranscriptEntries = []
            ProductLibraryPersistence.scheduleClear()
            log(\"transcript history and Library clear scheduled (\\(removed) cached entries)\")
        }
        rebuildMenu()
    }

"""
text = replace_once(text, marker, handler, "agent settings command handler")

text = replace_once(
    text,
    """        settings.recentTranscriptLimit = limit
        applyRecentTranscriptLimit()
        rebuildMenu()
""",
    """        handleProductSettingsCommand(
            .setRecentTranscriptMode(productRecentTranscriptMode(limit))
        )
""",
    "legacy recent-limit menu routes through shared handler",
)

text = replace_once(
    text,
    """    @objc private func clearHistoryClicked(_ sender: NSMenuItem) {
        guard !history.isEmpty else { return }
        let count = history.count
        history.removeAll()
        settings.recentTranscriptEntries = []
        log(\"history cleared (\\(count) entries)\")
        rebuildMenu()
    }
""",
    """    @objc private func clearHistoryClicked(_ sender: NSMenuItem) {
        guard !history.isEmpty else { return }
        handleProductSettingsCommand(.clearTranscriptHistory)
    }
""",
    "legacy clear-history menu clears durable Library too",
)

text = replace_once(
    text,
    """    @objc private func clearHistoryOverlayClicked(_ sender: NSButton) {
        guard !history.isEmpty else { return }
        let count = history.count
        history.removeAll()
        settings.recentTranscriptEntries = []
        log(\"history cleared from overlay (\\(count) entries)\")
        rebuildMenu()
        showHistoryOverlay()
    }
""",
    """    @objc private func clearHistoryOverlayClicked(_ sender: NSButton) {
        guard !history.isEmpty else { return }
        handleProductSettingsCommand(.clearTranscriptHistory)
        showHistoryOverlay()
    }
""",
    "overlay clear-history clears durable Library too",
)

path.write_text(text)
