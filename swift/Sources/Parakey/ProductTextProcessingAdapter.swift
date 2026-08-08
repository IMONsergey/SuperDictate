import Foundation
import SuperDictateCore

/// Compatibility seam from the legacy runtime settings types into the shared
/// deterministic product text processor.
func processDictationTextWithProductCore(
    rawTranscript: String,
    corrections: [TranscriptCorrection],
    removeFillerWords: Bool,
    language: DictationLanguage
) -> (text: String, appliedCorrectionCount: Int, removedFillerWordCount: Int) {
    let coreLanguage: SuperDictateTextLanguage
    switch language {
    case .auto:
        coreLanguage = .auto
    case .russian:
        coreLanguage = .russian
    default:
        coreLanguage = .other
    }

    let result = SuperDictateTextProcessor.process(
        rawTranscript: rawTranscript,
        options: SuperDictateTextProcessingOptions(
            language: coreLanguage,
            corrections: corrections.map {
                SuperDictateTextCorrection(source: $0.source, replacement: $0.replacement)
            },
            removeFillerWords: removeFillerWords
        )
    )

    return (
        result.text,
        result.appliedCorrectionCount,
        result.removedFillerWordCount
    )
}
