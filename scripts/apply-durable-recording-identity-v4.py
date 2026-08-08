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


main_path = Path("swift/Sources/Parakey/main.swift")
text = main_path.read_text()

# 1. Backward-compatible runtime history schema. All new fields are optional so
# existing UserDefaults JSON remains decodable without a destructive migration.
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

# Settings performs two decode/normalisation passes. They must preserve durable
# identity rather than silently stripping the optional fields on every read.
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
if count != 2 and text.count(new_clean) != 2:
    raise SystemExit(f"history normalisation: expected two source matches, found {count}")
if count == 2:
    text = text.replace(old_clean, new_clean)

# 2. Identity exists only for a real capture session and is allocated after the
# audio engine reports successful start. Failed starts therefore create no ghost
# recording identity.
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

# 3. Move identity into local release scope before any async ASR work. This makes
# later hotkey activity unable to overwrite the identity of an in-flight result.
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

# The nonstandard in-session release/recovery path has the same semantics and
# uses the actual captured sample count for source duration.
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

# 4. History remains the compatibility archive, but new rows now retain real
# source metadata. Older/recovered-v1 rows simply leave the fields nil.
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

# Both startup and post-dictation merge payloads must carry the same metadata.
pattern = re.compile(
    r"ProductLegacyHistoryValue\(\n(?P<i>\s+)text: \$0\.text,\n(?P=i)transcriptionDurationSeconds: \$0\.transcriptionDurationSeconds\n(?P<j>\s+)\)"
)
def payload_replacement(match: re.Match[str]) -> str:
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
text, value_count = pattern.subn(payload_replacement, text)
if value_count not in (0, 2):
    raise SystemExit(f"single-writer metadata payload: expected zero/already-applied or two matches, found {value_count}")
if value_count == 0 and text.count("sourceAudioDurationSeconds: $0.sourceAudioDurationSeconds") < 2:
    raise SystemExit("single-writer metadata payload is neither source nor applied form")

# 5. Runtime executable self-test: old JSON must decode and metadata-rich rows
# must round-trip through the actual TranscriptHistoryEntry Codable schema.
selftest_old = """    }

    private static func testDictationUsageStatistics() throws {
"""
selftest_new = """        let legacyHistoryJSON = Data(\"[{\\\"text\\\":\\\"legacy row\\\"}]\".utf8)
        let legacyHistoryDecoded = try JSONDecoder().decode(
            [TranscriptHistoryEntry].self,
            from: legacyHistoryJSON
        )
        try expect(
            legacyHistoryDecoded.first?.recordingID == nil
                && legacyHistoryDecoded.first?.createdAt == nil
                && legacyHistoryDecoded.first?.sourceAudioDurationSeconds == nil,
            equals: true,
            \"older history JSON should decode with unknown durable metadata\"
        )

        let metadataID = UUID(uuidString: \"01234567-89AB-CDEF-0123-456789ABCDEF\")!
        let metadataEntry = TranscriptHistoryEntry(
            text: \"metadata row\",
            transcriptionDurationSeconds: 0.75,
            recordingID: metadataID,
            createdAt: Date(timeIntervalSinceReferenceDate: 12_345),
            sourceAudioDurationSeconds: 8.5
        )
        let metadataRoundTrip = try JSONDecoder().decode(
            TranscriptHistoryEntry.self,
            from: JSONEncoder().encode(metadataEntry)
        )
        try expect(
            metadataRoundTrip,
            equals: metadataEntry,
            \"history Codable round-trip should preserve durable recording metadata\"
        )
    }

    private static func testDictationUsageStatistics() throws {
"""
if "older history JSON should decode with unknown durable metadata" not in text:
    count = text.count(selftest_old)
    if count != 1:
        raise SystemExit(f"history metadata self-test insertion: expected one match, found {count}")
    text = text.replace(selftest_old, selftest_new, 1)

main_path.write_text(text)

# 6. Switch the visible live projection only after the history schema above has
# been patched, so volatile and durable recording IDs change atomically.
bridge_path = Path("swift/Sources/Parakey/ProductRuntimeBridge.swift")
bridge = bridge_path.read_text()
bridge_old = """            SuperDictateLegacyHistoryEntry(
                text: $0.text,
                transcriptionDurationSeconds: $0.transcriptionDurationSeconds
            )"""
bridge_new = """            SuperDictateLegacyHistoryEntry(
                text: $0.text,
                transcriptionDurationSeconds: $0.transcriptionDurationSeconds,
                recordingID: $0.recordingID,
                createdAt: $0.createdAt,
                sourceAudioDurationSeconds: $0.sourceAudioDurationSeconds
            )"""
bridge = replace_once(
    bridge,
    bridge_old,
    bridge_new,
    "live bridge recording metadata",
)
bridge_path.write_text(bridge)

# Structural guardrails for the one-shot patch. These checks deliberately avoid
# transcript content and only assert schema/wiring facts.
final_main = main_path.read_text()
final_bridge = bridge_path.read_text()
assert "activeRecordingIdentity: ProductRecordingIdentity?" in final_main
assert final_main.count("recordingID: $0.recordingID") >= 2
assert final_main.count("sourceAudioDurationSeconds: $0.sourceAudioDurationSeconds") >= 2
assert "older history JSON should decode with unknown durable metadata" in final_main
assert "recordingID: $0.recordingID" in final_bridge
assert "sourceAudioDurationSeconds: $0.sourceAudioDurationSeconds" in final_bridge
