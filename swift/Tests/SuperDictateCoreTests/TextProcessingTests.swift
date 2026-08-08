import XCTest
@testable import SuperDictateCore

final class TextProcessingTests: XCTestCase {
    func testRussianUnknownTokenRepairMatchesCurrentRuntime() {
        XCTAssertEqual(
            SuperDictateTextProcessor.repairSpeechModelText(
                "<unk>лка. потом <unk>ж.",
                language: .russian
            ),
            "Ёлка. потом ёж."
        )
        XCTAssertEqual(
            SuperDictateTextProcessor.repairSpeechModelText(
                "Фраза! <UNK>лка",
                language: .auto
            ),
            "Фраза! Ёлка"
        )
    }

    func testOtherLanguageRemovesUnknownTokenAndRepairsPunctuation() {
        XCTAssertEqual(
            SuperDictateTextProcessor.repairSpeechModelText(
                "Hello <unk>,   world <UNK> !",
                language: .other
            ),
            "Hello, world!"
        )
    }

    func testCorrectionNormalizationDropsInvalidEntriesAndLetsLaterDuplicateWin() {
        var corrections = [
            SuperDictateTextCorrection(source: "  Yeti   Nano  ", replacement: " Blue mic "),
            SuperDictateTextCorrection(source: "yeti nano", replacement: "USB mic"),
            SuperDictateTextCorrection(source: "", replacement: "ignored"),
            SuperDictateTextCorrection(source: "empty replacement", replacement: "   "),
            SuperDictateTextCorrection(source: "nul\u{0}source", replacement: "ignored"),
        ]
        corrections += (0..<(SuperDictateTextProcessor.maximumCorrections + 3)).map {
            SuperDictateTextCorrection(source: "source-\($0)", replacement: "replacement-\($0)")
        }
        corrections.append(
            SuperDictateTextCorrection(source: "source-0", replacement: "updated")
        )

        let normalized = SuperDictateTextProcessor.normalizedCorrections(corrections)

        XCTAssertEqual(normalized.count, SuperDictateTextProcessor.maximumCorrections)
        XCTAssertEqual(
            normalized.first,
            SuperDictateTextCorrection(source: "yeti nano", replacement: "USB mic")
        )
        XCTAssertEqual(
            normalized.first { $0.source == "source-0" }?.replacement,
            "updated"
        )
        XCTAssertFalse(
            normalized.contains { $0.source == "source-\(SuperDictateTextProcessor.maximumCorrections)" }
        )
    }

    func testCorrectionsPreferLongPhrasesAndRespectWordBoundaries() {
        let applied = SuperDictateTextProcessor.applyCorrections(
            "parakeet tdt and parakeetish and PARakeet",
            corrections: [
                SuperDictateTextCorrection(source: "parakeet", replacement: "Parakey"),
                SuperDictateTextCorrection(source: "parakeet tdt", replacement: "Parakeet TDT"),
            ]
        )

        XCTAssertEqual(applied.text, "Parakeet TDT and parakeetish and Parakey")
        XCTAssertEqual(applied.appliedCount, 2)
    }

    func testFillerRemovalPreservesCapitalizationAndHyphenatedWords() {
        let stripped = SuperDictateTextProcessor.removeFillerWords(
            "Um, hello. First. Um hello. I like cats. uh-huh stays."
        )

        XCTAssertEqual(
            stripped.text,
            "Hello. First. Hello. I like cats. uh-huh stays."
        )
        XCTAssertEqual(stripped.removedCount, 2)
    }

    func testFillerCleanupHandlesRunsAndTerminalPunctuation() {
        let stripped = SuperDictateTextProcessor.removeFillerWords(
            "Well, um, uh, ah, done. Um? What? That's all, erm."
        )

        XCTAssertEqual(stripped.text, "Well, done. What? That's all.")
        XCTAssertEqual(stripped.removedCount, 5)
    }

    func testExplicitCorrectionRunsBeforeFillerRemoval() {
        let result = SuperDictateTextProcessor.process(
            rawTranscript: "  uh, hello  ",
            options: SuperDictateTextProcessingOptions(
                language: .other,
                corrections: [
                    SuperDictateTextCorrection(source: "uh", replacement: "USB")
                ],
                removeFillerWords: true
            )
        )

        XCTAssertEqual(result.text, "USB, hello")
        XCTAssertEqual(result.appliedCorrectionCount, 1)
        XCTAssertEqual(result.removedFillerWordCount, 0)
    }

    func testPipelineReportsCorrectionAndFillerCounts() {
        let result = SuperDictateTextProcessor.process(
            rawTranscript: "Um, parakeet tdt works",
            options: SuperDictateTextProcessingOptions(
                corrections: [
                    SuperDictateTextCorrection(source: "parakeet tdt", replacement: "Parakeet TDT")
                ],
                removeFillerWords: true
            )
        )

        XCTAssertEqual(result.text, "Parakeet TDT works")
        XCTAssertEqual(result.appliedCorrectionCount, 1)
        XCTAssertEqual(result.removedFillerWordCount, 1)
    }
}
