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
    """        history = next
        settings.recentTranscriptEntries = history
        if rebuildMenuAfterPersisting {
            rebuildMenu()
        }
""",
    """        history = next
        settings.recentTranscriptEntries = history
        ProductLibraryPersistence.scheduleLegacyHistoryMerge(
            history.map {
                ProductLegacyHistoryValue(
                    text: $0.text,
                    transcriptionDurationSeconds: $0.transcriptionDurationSeconds
                )
            }
        )
        if rebuildMenuAfterPersisting {
            rebuildMenu()
        }
""",
    "successful history -> durable Library hook",
)

path.write_text(text)
