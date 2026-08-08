from pathlib import Path
import re


path = Path("swift/Sources/Parakey/main.swift")
text = path.read_text()

speech_pattern = r"enum SpeechModelTextRepair \{.*?\n\}\n\nenum TranscriptCorrector \{"
speech_replacement = """enum SpeechModelTextRepair {
    static func apply(to text: String, language: DictationLanguage = .auto) -> String {
        processDictationTextWithProductCore(
            rawTranscript: text,
            corrections: [],
            removeFillerWords: false,
            language: language
        ).text
    }
}

enum TranscriptCorrector {"""
text, count = re.subn(speech_pattern, speech_replacement, text, count=1, flags=re.S)
if count != 1:
    raise SystemExit(f"SpeechModelTextRepair collapse expected one match, found {count}")

correction_pattern = r"enum TranscriptCorrector \{.*?\n\}\n\n// Deterministic regex pass that strips"
correction_replacement = """enum TranscriptCorrector {
    static func apply(
        to text: String,
        corrections: [TranscriptCorrection]
    ) -> (text: String, appliedCount: Int) {
        let result = processDictationTextWithProductCore(
            rawTranscript: text,
            corrections: corrections,
            removeFillerWords: false,
            language: .auto
        )
        return (result.text, result.appliedCorrectionCount)
    }
}

// Deterministic regex pass that strips"""
text, count = re.subn(correction_pattern, correction_replacement, text, count=1, flags=re.S)
if count != 1:
    raise SystemExit(f"TranscriptCorrector collapse expected one match, found {count}")

filler_pattern = (
    r"// Deterministic regex pass that strips standalone non-word fillers.*?"
    r"enum FillerWordRemover \{.*?\n\}\n\nprivate enum RecordingReleaseAction"
)
filler_replacement = """// Compatibility shim retained for the unchanged runtime self-test suite.
// The production implementation lives in `SuperDictateTextProcessor`.
enum FillerWordRemover {
    static func apply(to text: String) -> (text: String, removedCount: Int) {
        let result = processDictationTextWithProductCore(
            rawTranscript: text,
            corrections: [],
            removeFillerWords: true,
            language: .auto
        )
        return (result.text, result.removedFillerWordCount)
    }
}

private enum RecordingReleaseAction"""
text, count = re.subn(filler_pattern, filler_replacement, text, count=1, flags=re.S)
if count != 1:
    raise SystemExit(f"FillerWordRemover collapse expected one match, found {count}")

path.write_text(text)
