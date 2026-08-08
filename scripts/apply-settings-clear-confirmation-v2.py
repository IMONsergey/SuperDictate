from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one source match, found {count}")
    return text.replace(old, new, 1)


path = Path("swift/Sources/SuperDictateUI/SuperDictateSettingsView.swift")
text = path.read_text()
text = replace_once(
    text,
    """    @State private var section: SuperDictateSettingsSection = .dictation

    public init(
""",
    """    @State private var section: SuperDictateSettingsSection = .dictation
    @State private var showClearHistoryConfirmation = false

    public init(
""",
    "clear-history confirmation state",
)
text = replace_once(
    text,
    """        .frame(minWidth: 760, minHeight: 520)
    }
""",
    """        .frame(minWidth: 760, minHeight: 520)
        .confirmationDialog(
            text(\"Очистить локальную историю?\", \"Clear local history?\"),
            isPresented: $showClearHistoryConfirmation,
            titleVisibility: .visible
        ) {
            Button(text(\"Очистить историю\", \"Clear History\"), role: .destructive) {
                onCommand(.clearTranscriptHistory)
            }
            Button(text(\"Отмена\", \"Cancel\"), role: .cancel) {}
        } message: {
            Text(text(
                \"Будут удалены recent-history cache и локальная Library. Новые диктовки снова начнут сохраняться, если режим истории не выключен.\",
                \"The recent-history cache and local Library will be deleted. New dictations will be stored again unless history is Off.\"
            ))
        }
    }
""",
    "clear-history confirmation dialog",
)
text = replace_once(
    text,
    """            Button(role: .destructive) {
                onCommand(.clearTranscriptHistory)
            } label: {
""",
    """            Button(role: .destructive) {
                showClearHistoryConfirmation = true
            } label: {
""",
    "clear-history button asks first",
)
path.write_text(text)
