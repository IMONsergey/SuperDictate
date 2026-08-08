from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one source match, found {count}")
    return text.replace(old, new, 1)


path = Path("swift/Sources/SuperDictateUI/SuperDictateMainView.swift")
text = path.read_text()

text = replace_once(
    text,
    """    private let snapshot: SuperDictateProductSnapshot
    private let language: SuperDictateInterfaceLanguage
""",
    """    private let snapshot: SuperDictateProductSnapshot
    private let memoryDocuments: [SuperDictateMemoryDocument]
    private let language: SuperDictateInterfaceLanguage
""",
    "main view memory documents property",
)

text = replace_once(
    text,
    """    public init(
        snapshot: SuperDictateProductSnapshot,
        language: SuperDictateInterfaceLanguage = .english,
        onCommand: @escaping (SuperDictateCommand) -> Void = { _ in }
    ) {
        self.snapshot = snapshot
        self.language = language
        self.onCommand = onCommand
    }
""",
    """    public init(
        snapshot: SuperDictateProductSnapshot,
        memoryDocuments: [SuperDictateMemoryDocument] = [],
        language: SuperDictateInterfaceLanguage = .english,
        onCommand: @escaping (SuperDictateCommand) -> Void = { _ in }
    ) {
        self.snapshot = snapshot
        self.memoryDocuments = memoryDocuments
        self.language = language
        self.onCommand = onCommand
    }
""",
    "main view initializer",
)

text = replace_once(
    text,
    """            case .library:
                LibraryView(recordings: snapshot.recordings, copy: copy, openRecording: openRecording)
            case .tasks:
                TasksView(tasks: snapshot.tasks, copy: copy, onCommand: onCommand)
            case .ask:
                AskView(copy: copy)
""",
    """            case .library:
                SuperDictateSearchableLibraryView(
                    recordings: snapshot.recordings,
                    memoryDocuments: memoryDocuments,
                    language: language,
                    onOpenRecording: openRecording
                )
            case .tasks:
                TasksView(tasks: snapshot.tasks, copy: copy, onCommand: onCommand)
            case .ask:
                SuperDictateEvidenceAskView(
                    documents: memoryDocuments,
                    language: language,
                    onOpenEvidence: openEvidence
                )
""",
    "destination Library/Ask wiring",
)

text = replace_once(
    text,
    """    private func openRecording(_ recording: SuperDictateRecording) {
        selectedRecordingID = recording.id
        recordingSection = recording.summary?.isEmpty == false ? .summary : .transcript
        onCommand(.openRecording(recording.id))
    }
}
""",
    """    private func openRecording(_ recording: SuperDictateRecording) {
        selectedRecordingID = recording.id
        recordingSection = recording.summary?.isEmpty == false ? .summary : .transcript
        onCommand(.openRecording(recording.id))
    }

    private func openEvidence(_ hit: SuperDictateMemorySearchHit) {
        guard snapshot.recordings.contains(where: { $0.id == hit.recordingID }) else {
            return
        }
        selectedRecordingID = hit.recordingID
        recordingSection = .transcript
        onCommand(.openRecording(hit.recordingID))
    }
}
""",
    "evidence source navigation",
)

path.write_text(text)
