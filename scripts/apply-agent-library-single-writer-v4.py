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
    """        history = settings.recentTranscriptEntries\n        importDictationUsageFromLogIfNeeded()\n""",
    """        history = settings.recentTranscriptEntries\n        if settings.recentTranscriptLimit == .off {\n            ProductLibraryPersistence.scheduleClear()\n        } else {\n            ProductLibraryPersistence.scheduleLegacyHistoryMerge(\n                history.map {\n                    ProductLegacyHistoryValue(\n                        text: $0.text,\n                        transcriptionDurationSeconds: $0.transcriptionDurationSeconds\n                    )\n                }\n            )\n        }\n        importDictationUsageFromLogIfNeeded()\n""",
    "agent startup Library migration",
)

text = replace_once(
    text,
    """        history = next\n        settings.recentTranscriptEntries = history\n        if rebuildMenuAfterPersisting {\n            rebuildMenu()\n        }\n""",
    """        history = next\n        settings.recentTranscriptEntries = history\n        ProductLibraryPersistence.scheduleLegacyHistoryMerge(\n            history.map {\n                ProductLegacyHistoryValue(\n                    text: $0.text,\n                    transcriptionDurationSeconds: $0.transcriptionDurationSeconds\n                )\n            }\n        )\n        if rebuildMenuAfterPersisting {\n            rebuildMenu()\n        }\n""",
    "successful history Library persistence",
)

text = replace_once(
    text,
    """    private func applyRecentTranscriptLimit() {\n        guard settings.recentTranscriptLimit == .off, !history.isEmpty else { return }\n        let removed = history.count\n        history.removeAll()\n        settings.recentTranscriptEntries = []\n        log(\"recent transcript history disabled and cleared (\\(removed) entries)\")\n    }\n""",
    """    private func applyRecentTranscriptLimit() {\n        guard settings.recentTranscriptLimit == .off else { return }\n        let removed = history.count\n        history.removeAll()\n        settings.recentTranscriptEntries = []\n        ProductLibraryPersistence.scheduleClear()\n        log(\"recent transcript history disabled and Library clear scheduled (\\(removed) cached entries)\")\n    }\n""",
    "history off durable clear",
)

path.write_text(text)
