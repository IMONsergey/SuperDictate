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

# Keep the Settings IPC observer beside the already-trusted product capture
# observer. Both are owned by the background agent main actor.
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

# One agent-owned mutation handler is the only place where side-effectful
# transcript-history settings are applied. This prevents native Settings, legacy
# menu actions and overlay actions from acquiring subtly different deletion
# semantics.
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
            // Always clear durable Library even when the bounded recent cache is
            // already empty. Otherwise an explicit privacy deletion can become a
            // no-op while older durable rows remain on disk.
            ProductLibraryPersistence.scheduleClear()
            log(\"transcript history and Library clear scheduled (\\(removed) cached entries)\")
        }
        rebuildMenu()
    }

"""
text = replace_once(text, marker, handler, "agent settings command handler")

# Legacy recent-list menu uses the exact same typed mapping and side effects as
# native Settings; it no longer owns a separate mutation path.
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

# Full-clear actions deliberately have no `history.isEmpty` guard: Library may
# contain older rows even when the bounded visible cache is empty.
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
        handleProductSettingsCommand(.clearTranscriptHistory)
    }
""",
    "legacy full clear works with empty recent cache",
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
        handleProductSettingsCommand(.clearTranscriptHistory)
        showHistoryOverlay()
    }
""",
    "overlay full clear works with empty recent cache",
)

path.write_text(text)

# Structural assertions are deliberately content-free/privacy-safe.
final = path.read_text()
assert "productSettingsCommandObserver: ProductSettingsCommandObserver?" in final
assert "handleProductSettingsCommand(_ command: ProductAgentSettingsCommand)" in final
assert final.count("ProductLibraryPersistence.scheduleClear()") >= 3
assert "guard !history.isEmpty else { return }" not in final[final.find("@objc private func clearHistoryClicked"):final.find("private func toggleHistoryOverlay")]
