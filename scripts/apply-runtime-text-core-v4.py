from pathlib import Path

path = Path("swift/Sources/Parakey/main.swift")
text = path.read_text()
old = """private func processedDictationText(rawTranscript: String,
                                    corrections: [TranscriptCorrection],
                                    removeFillerWords: Bool,
                                    language: DictationLanguage = .auto) -> DictationTextProcessingResult {
    let trimmed = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
    let repaired = SpeechModelTextRepair.apply(to: trimmed, language: language)
    let corrected = TranscriptCorrector.apply(to: repaired, corrections: corrections)

    guard removeFillerWords else {
        return DictationTextProcessingResult(text: corrected.text,
                                             appliedCorrectionCount: corrected.appliedCount,
                                             removedFillerWordCount: 0)
    }

    let stripped = FillerWordRemover.apply(to: corrected.text)
    return DictationTextProcessingResult(text: stripped.text,
                                         appliedCorrectionCount: corrected.appliedCount,
                                         removedFillerWordCount: stripped.removedCount)
}
"""
new = """private func processedDictationText(rawTranscript: String,
                                    corrections: [TranscriptCorrection],
                                    removeFillerWords: Bool,
                                    language: DictationLanguage = .auto) -> DictationTextProcessingResult {
    let processed = processDictationTextWithProductCore(
        rawTranscript: rawTranscript,
        corrections: corrections,
        removeFillerWords: removeFillerWords,
        language: language
    )
    return DictationTextProcessingResult(
        text: processed.text,
        appliedCorrectionCount: processed.appliedCorrectionCount,
        removedFillerWordCount: processed.removedFillerWordCount
    )
}
"""
if new in text:
    raise SystemExit("runtime text core hook is already applied")
count = text.count(old)
if count != 1:
    raise SystemExit(f"processedDictationText: expected exactly one source match, found {count}")
path.write_text(text.replace(old, new, 1))
