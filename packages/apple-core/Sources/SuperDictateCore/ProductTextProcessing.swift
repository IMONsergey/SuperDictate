import Foundation

public enum SuperDictateTextLanguage: String, Codable, CaseIterable, Sendable {
    case auto
    case russian = "ru"
    /// Any language where Parakeet's `<unk>` token must be removed rather than
    /// interpreted as the Russian letter ё.
    case nonRussian = "non_ru"
}

public struct SuperDictateTextCorrection: Codable, Equatable, Sendable {
    public var source: String
    public var replacement: String

    public init(source: String, replacement: String) {
        self.source = source
        self.replacement = replacement
    }
}

public struct SuperDictateTextProcessingOptions: Codable, Equatable, Sendable {
    public var language: SuperDictateTextLanguage
    public var corrections: [SuperDictateTextCorrection]
    public var removeFillerWords: Bool

    public init(
        language: SuperDictateTextLanguage = .auto,
        corrections: [SuperDictateTextCorrection] = [],
        removeFillerWords: Bool = false
    ) {
        self.language = language
        self.corrections = corrections
        self.removeFillerWords = removeFillerWords
    }
}

public struct SuperDictateTextProcessingResult: Codable, Equatable, Sendable {
    public let text: String
    public let appliedCorrectionCount: Int
    public let removedFillerWordCount: Int

    public init(
        text: String,
        appliedCorrectionCount: Int,
        removedFillerWordCount: Int
    ) {
        self.text = text
        self.appliedCorrectionCount = max(0, appliedCorrectionCount)
        self.removedFillerWordCount = max(0, removedFillerWordCount)
    }
}

/// Pure deterministic text processing shared by instant dictation and longer
/// recording workflows.
///
/// Order is an invariant:
/// 1. trim raw ASR output;
/// 2. repair known model artifacts;
/// 3. apply explicit user corrections;
/// 4. optionally remove conservative filler words.
///
/// User corrections intentionally run before filler stripping so explicit user
/// intent always wins.
public enum SuperDictateTextProcessor {
    public static let maximumCorrections = 512
    public static let maximumCorrectionSourceBytes = 512
    public static let maximumCorrectionReplacementBytes = 4_096

    public static func process(
        rawTranscript: String,
        options: SuperDictateTextProcessingOptions = .init()
    ) -> SuperDictateTextProcessingResult {
        let trimmed = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let repaired = repairSpeechModelText(trimmed, language: options.language)
        let corrected = applyCorrections(repaired, corrections: options.corrections)

        guard options.removeFillerWords else {
            return SuperDictateTextProcessingResult(
                text: corrected.text,
                appliedCorrectionCount: corrected.appliedCount,
                removedFillerWordCount: 0
            )
        }

        let stripped = removeFillerWords(corrected.text)
        return SuperDictateTextProcessingResult(
            text: stripped.text,
            appliedCorrectionCount: corrected.appliedCount,
            removedFillerWordCount: stripped.removedCount
        )
    }

    public static func normalizedCorrections(
        _ corrections: [SuperDictateTextCorrection]
    ) -> [SuperDictateTextCorrection] {
        var result: [SuperDictateTextCorrection] = []
        var indexByKey: [String: Int] = [:]

        for correction in corrections {
            guard let cleaned = normalizedCorrection(correction) else { continue }
            let key = correctionKey(cleaned.source)

            if let existingIndex = indexByKey[key] {
                result[existingIndex] = cleaned
                continue
            }

            guard result.count < maximumCorrections else { continue }
            indexByKey[key] = result.count
            result.append(cleaned)
        }

        return result
    }

    public static func repairSpeechModelText(
        _ text: String,
        language: SuperDictateTextLanguage = .auto
    ) -> String {
        guard text.localizedCaseInsensitiveContains("<unk>") else { return text }

        let replaceWithYo = language == .auto || language == .russian
        var result = ""
        result.reserveCapacity(text.count)
        var index = text.startIndex

        while index < text.endIndex {
            if matchesUnknownToken(in: text, at: index) {
                if replaceWithYo {
                    result.append(shouldCapitalizeYo(before: result) ? "Ё" : "ё")
                }
                index = text.index(index, offsetBy: 5)
            } else {
                result.append(text[index])
                index = text.index(after: index)
            }
        }

        if !replaceWithYo {
            result = result
                .replacingOccurrences(
                    of: #"\s+([.,!?;:])"#,
                    with: "$1",
                    options: .regularExpression
                )
                .replacingOccurrences(
                    of: #"[ \t]+"#,
                    with: " ",
                    options: .regularExpression
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return result
    }

    public static func applyCorrections(
        _ text: String,
        corrections: [SuperDictateTextCorrection]
    ) -> (text: String, appliedCount: Int) {
        struct Match {
            let range: NSRange
            let replacement: String
        }

        let active = normalizedCorrections(corrections)
            .sorted { lhs, rhs in
                if lhs.source.count != rhs.source.count {
                    return lhs.source.count > rhs.source.count
                }
                return lhs.source.localizedCaseInsensitiveCompare(rhs.source) == .orderedAscending
            }

        guard !text.isEmpty, !active.isEmpty else { return (text, 0) }

        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        var matches: [Match] = []

        for correction in active {
            guard let pattern = correctionPattern(for: correction.source),
                  let regex = try? NSRegularExpression(
                    pattern: pattern,
                    options: [.caseInsensitive]
                  ) else {
                continue
            }

            regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                guard let range = match?.range,
                      range.location != NSNotFound,
                      !matches.contains(where: {
                        NSIntersectionRange($0.range, range).length > 0
                      }) else {
                    return
                }
                matches.append(Match(range: range, replacement: correction.replacement))
            }
        }

        guard !matches.isEmpty else { return (text, 0) }

        let rewritten = NSMutableString(string: text)
        for match in matches.sorted(by: { $0.range.location > $1.range.location }) {
            rewritten.replaceCharacters(in: match.range, with: match.replacement)
        }
        return (rewritten as String, matches.count)
    }

    public static func removeFillerWords(
        _ text: String
    ) -> (text: String, removedCount: Int) {
        guard !text.isEmpty else { return (text, 0) }

        let alternation = fillerPatterns.joined(separator: "|")
        let pattern = #"(?i)(?<![\p{L}\p{N}'\-])("#
            + alternation
            + #")(?![\p{L}\p{N}'\-])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return (text, 0)
        }

        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: fullRange)
        guard !matches.isEmpty else { return (text, 0) }

        let capitalizationTargets = capitalizationRepairTargets(for: matches, in: text)
        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            mutable.replaceCharacters(in: match.range, with: "")
        }

        var result = mutable as String
        result = result.replacingOccurrences(
            of: #"\s*,(?:\s*,)+"#,
            with: ",",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"([.!?])\s+[,.;:!?]+\s*"#,
            with: "$1 ",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\s+([.,!?;:])"#,
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #",+([.!?;:])"#,
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"^[\s,.;:!?]+"#,
            with: "",
            options: .regularExpression
        )
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        result = restoringCapitalization(in: result, targets: capitalizationTargets)

        return (result, matches.count)
    }

    private enum CapitalizationRepairTarget: Hashable {
        case start
        case afterSentenceTerminator(Int)
    }

    private static let fillerPatterns = ["um+", "uh+", "ah+", "er", "erm", "hm+"]

    private static func normalizedCorrection(
        _ correction: SuperDictateTextCorrection
    ) -> SuperDictateTextCorrection? {
        let source = correction.source
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        let replacement = correction.replacement
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !source.isEmpty,
              !replacement.isEmpty,
              source.utf8.count <= maximumCorrectionSourceBytes,
              replacement.utf8.count <= maximumCorrectionReplacementBytes,
              !source.unicodeScalars.contains(where: { $0.value == 0 }),
              !replacement.unicodeScalars.contains(where: { $0.value == 0 }) else {
            return nil
        }

        return SuperDictateTextCorrection(source: source, replacement: replacement)
    }

    private static func correctionKey(_ source: String) -> String {
        source.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    private static func correctionPattern(for source: String) -> String? {
        let parts = source
            .split(whereSeparator: { $0.isWhitespace })
            .map { NSRegularExpression.escapedPattern(for: String($0)) }
        guard !parts.isEmpty else { return nil }
        return #"(?<![\p{L}\p{N}_])"#
            + parts.joined(separator: #"\s+"#)
            + #"(?![\p{L}\p{N}_])"#
    }

    private static func matchesUnknownToken(
        in text: String,
        at index: String.Index
    ) -> Bool {
        let token = "<unk>"
        guard let end = text.index(
            index,
            offsetBy: token.count,
            limitedBy: text.endIndex
        ) else {
            return false
        }
        return text[index..<end].lowercased() == token
    }

    private static func shouldCapitalizeYo(before prefix: String) -> Bool {
        guard let last = prefix.last(where: { !$0.isWhitespace }) else { return true }
        return ".!?".contains(last)
    }

    private static func capitalizationRepairTargets(
        for matches: [NSTextCheckingResult],
        in text: String
    ) -> Set<CapitalizationRepairTarget> {
        Set(matches.compactMap { match in
            guard let range = Range(match.range, in: text),
                  text[range].first?.isUppercase == true else {
                return nil
            }
            return capitalizationRepairTarget(for: range, in: text)
        })
    }

    private static func capitalizationRepairTarget(
        for range: Range<String.Index>,
        in text: String
    ) -> CapitalizationRepairTarget? {
        var index = range.lowerBound
        while index > text.startIndex {
            let previous = text.index(before: index)
            let character = text[previous]
            if character.isWhitespace || isBoundaryWrapper(character) {
                index = previous
                continue
            }
            guard isSentenceTerminator(character) else { return nil }
            return .afterSentenceTerminator(
                sentenceTerminatorOrdinal(at: previous, in: text)
            )
        }
        return .start
    }

    private static func sentenceTerminatorOrdinal(
        at target: String.Index,
        in text: String
    ) -> Int {
        var ordinal = 0
        var index = text.startIndex
        while index <= target {
            if isSentenceTerminator(text[index]) {
                ordinal += 1
            }
            index = text.index(after: index)
        }
        return ordinal
    }

    private static func restoringCapitalization(
        in text: String,
        targets: Set<CapitalizationRepairTarget>
    ) -> String {
        guard !targets.isEmpty, !text.isEmpty else { return text }

        let sentenceTargets = Set(targets.compactMap { target -> Int? in
            guard case .afterSentenceTerminator(let ordinal) = target else {
                return nil
            }
            return ordinal
        })
        var result = ""
        result.reserveCapacity(text.count)
        var sentenceTerminatorOrdinal = 0
        var shouldCapitalizeNextWord = targets.contains(.start)

        for character in text {
            if shouldCapitalizeNextWord {
                if character.isLowercase {
                    result += character.uppercased()
                    shouldCapitalizeNextWord = false
                    continue
                }
                if character.isLetter || character.isNumber {
                    shouldCapitalizeNextWord = false
                }
            }

            result.append(character)

            if isSentenceTerminator(character) {
                sentenceTerminatorOrdinal += 1
                if sentenceTargets.contains(sentenceTerminatorOrdinal) {
                    shouldCapitalizeNextWord = true
                }
            } else if shouldCapitalizeNextWord,
                      !character.isWhitespace,
                      !isBoundaryWrapper(character),
                      !isOrphanSeparator(character) {
                shouldCapitalizeNextWord = false
            }
        }

        return result
    }

    private static func isSentenceTerminator(_ character: Character) -> Bool {
        character == "." || character == "!" || character == "?"
    }

    private static func isBoundaryWrapper(_ character: Character) -> Bool {
        "\"'“”‘’([{".contains(character)
    }

    private static func isOrphanSeparator(_ character: Character) -> Bool {
        ",.;:!?".contains(character)
    }
}
