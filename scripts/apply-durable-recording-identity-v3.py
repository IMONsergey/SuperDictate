from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one source match, found {count}")
    return text.replace(old, new, 1)


def replace_regex_once(text: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one regex match, found {count}")
    return updated


path = Path("swift/Sources/Parakey/main.swift")
text = path.read_text()

text = replace_regex_once(
    text,
    r"struct TranscriptHistoryEntry: Codable, Equatable \{.*?\n\}\n\nfunc limitedRecentTranscriptEntries",
    """struct TranscriptHistoryEntry: Codable, Equatable {
    let text: String
    let transcriptionDurationSeconds: Double?
    let asrTiming: ASRTimingBreakdown?
    let recordingID: UUID?
    let createdAt: Date?
    let sourceAudioDurationSeconds: Double?

    init(text: String,
         transcriptionDurationSeconds: Double? = nil,
         asrTiming: ASRTimingBreakdown? = nil,
         recordingID: UUID? = nil,
         createdAt: Date? = nil,
         sourceAudioDurationSeconds: Double? = nil) {
        self.text = text
        if let duration = transcriptionDurationSeconds,
           duration.isFinite, duration >= 0 {
            self.transcriptionDurationSeconds = duration
        } else {
            self.transcriptionDurationSeconds = nil
        }
        self.asrTiming = asrTiming
        self.recordingID = recordingID
        self.createdAt = createdAt
        if let duration = sourceAudioDurationSeconds,
           duration.isFinite, duration >= 0 {
            self.sourceAudioDurationSeconds = duration
        } else {
            self.sourceAudioDurationSeconds = nil
        }
    }
}

func limitedRecentTranscriptEntries""",
    "TranscriptHistoryEntry metadata schema",
)

old_clean = """                    return TranscriptHistoryEntry(
                        text: text,
                        transcriptionDurationSeconds: entry.transcriptionDurationSeconds,
                        asrTiming: entry.asrTiming
                    )"""
new_clean = """                    return TranscriptHistoryEntry(
                        text: text,
                        transcriptionDurationSeconds: entry.transcriptionDurationSeconds,
                        asrTiming: entry.asrTiming,
                        recordingID: entry.recordingID,
                        createdAt: entry.createdAt,
                        sourceAudioDurationSeconds: entry.sourceAudioDurationSeconds
                    )"""
count = text.count(old_clean)
if count != 2:
    raise SystemExit(f"history normalisation: expected exactly two source matches, found {count}")
text = text.replace(old_clean, new_clean)

text = replace_once(
    text,
    """    private var isRecording = false
    private var isBusy = false
""",
    """    private var isRecording = false
    private var activeRecordingIdentity: ProductRecordingIdentity?
    private var isBusy = false
""",
    "active recording identity property",
)

text = replace_once(
    text,
    """        isRecording = true
        if setupChecklistWindow?.isVisible == true {
""",
    """        isRecording = true
        activeRecordingIdentity = .now()
        if setupChecklistWindow?.isVisible == true {
""",
    "allocate recording identity after audio start",
)

text = replace_once(
    text,
    """        isRecording = false
        stopRecordingLevelMeter(hideHUD: false)
        cancelMaxDurationAutoRelease()
""",
    """        let recordingIdentity = activeRecordingIdentity
        activeRecordingIdentity = nil
        isRecording = false
        stopRecordingLevelMeter(hideHUD: false)
        cancelMaxDurationAutoRelease()
""",
    "normal release takes active identity",
)

text = replace_once(
    text,
    """                        addToHistory(
                            cleaned,
                            transcriptionDurationSeconds: asrTiming.totalSeconds,
                            asrTiming: asrTiming,
                            rebuildMenuAfterPersisting: false
                        )
""",
    """                        addToHistory(
                            cleaned,
                            transcriptionDurationSeconds: asrTiming.totalSeconds,
                            asrTiming: asrTiming,
                            recordingID: recordingIdentity?.id,
                            createdAt: recordingIdentity?.createdAt,
                            sourceAudioDurationSeconds: dur,
                            rebuildMenuAfterPersisting: false
                        )
""",
    "normal history carries real recording metadata",
)

text = replace_once(
    text,
    """        cancelMaxDurationAutoRelease()
        let captured = audio.endRecording()
        let duration = Double(captured.samples.count) / SAMPLE_RATE
        isRecording = false
""",
    """        let recordingIdentity = activeRecordingIdentity
        activeRecordingIdentity = nil
        cancelMaxDurationAutoRelease()
        let captured = audio.endRecording()
        let duration = Double(captured.samples.count) / SAMPLE_RATE
        isRecording = false
""",
    "recovery takes active identity",
)

text = replace_once(
    text,
    """                        addToHistory(
                            processed.text,
                            transcriptionDurationSeconds: timing.totalSeconds,
                            asrTiming: timing
                        )
""",
    """                        addToHistory(
                            processed.text,
                            transcriptionDurationSeconds: timing.totalSeconds,
                            asrTiming: timing,
                            recordingID: recordingIdentity?.id,
                            createdAt: recordingIdentity?.createdAt,
                            sourceAudioDurationSeconds: duration
                        )
""",
    "recovery history carries real recording metadata",
)

text = replace_once(
    text,
    """    private func addToHistory(_ text: String,
                              transcriptionDurationSeconds: Double?,
                              asrTiming: ASRTimingBreakdown? = nil,
                              rebuildMenuAfterPersisting: Bool = true) {
""",
    """    private func addToHistory(_ text: String,
                              transcriptionDurationSeconds: Double?,
                              asrTiming: ASRTimingBreakdown? = nil,
                              recordingID: UUID? = nil,
                              createdAt: Date? = nil,
                              sourceAudioDurationSeconds: Double? = nil,
                              rebuildMenuAfterPersisting: Bool = true) {
""",
    "history function metadata parameters",
)

text = replace_once(
    text,
    """        let entry = TranscriptHistoryEntry(
            text: text,
            transcriptionDurationSeconds: transcriptionDurationSeconds,
            asrTiming: asrTiming
        )
""",
    """        let entry = TranscriptHistoryEntry(
            text: text,
            transcriptionDurationSeconds: transcriptionDurationSeconds,
            asrTiming: asrTiming,
            recordingID: recordingID,
            createdAt: createdAt,
            sourceAudioDurationSeconds: sourceAudioDurationSeconds
        )
""",
    "history entry stores recording metadata",
)

pattern = re.compile(
    r"ProductLegacyHistoryValue\(\n(?P<i>\s+)text: \$0\.text,\n(?P=i)transcriptionDurationSeconds: \$0\.transcriptionDurationSeconds\n(?P<j>\s+)\)"
)
def repl(match: re.Match[str]) -> str:
    i = match.group("i")
    j = match.group("j")
    return (
        "ProductLegacyHistoryValue(\n"
        f"{i}text: $0.text,\n"
        f"{i}transcriptionDurationSeconds: $0.transcriptionDurationSeconds,\n"
        f"{i}recordingID: $0.recordingID,\n"
        f"{i}createdAt: $0.createdAt,\n"
        f"{i}sourceAudioDurationSeconds: $0.sourceAudioDurationSeconds\n"
        f"{j})"
    )
text, value_count = pattern.subn(repl, text)
if value_count != 2:
    raise SystemExit(f"single-writer metadata payload: expected two matches, found {value_count}")

path.write_text(text)
