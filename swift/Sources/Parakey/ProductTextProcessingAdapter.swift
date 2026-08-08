import Foundation
import SuperDictateCore

/// Compatibility seam from the legacy runtime settings types into the shared
/// deterministic product text processor.
///
/// Keeping this adapter inside the Parakey module lets `main.swift` migrate call
/// sites without importing product-core details or changing existing self-test
/// result types in the same commit.
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
                SuperDictateTextCorrection(
                    source: $0.source,
                    replacement: $0.replacement
                )
            },
            removeFillerWords: removeFillerWords
        )
    )

    return (
        text: result.text,
        appliedCorrectionCount: result.appliedCorrectionCount,
        removedFillerWordCount: result.removedFillerWordCount
    )
}
