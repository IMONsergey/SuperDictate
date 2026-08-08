import CryptoKit
import Foundation

/// Runtime-history projection accepted by the durable Library migrator.
///
/// Old history rows only know transcript text + ASR processing duration. Newer
/// runtime rows may additionally provide a real recording UUID, capture time and
/// source-audio duration. ASR duration is deliberately kept separate from audio
/// duration so the product never presents processing time as recording length.
public struct SuperDictateLegacyHistoryEntry: Equatable, Sendable {
    public var text: String
    public var transcriptionDurationSeconds: Double?
    public var recordingID: UUID?
    public var createdAt: Date?
    public var sourceAudioDurationSeconds: Double?

    public init(
        text: String,
        transcriptionDurationSeconds: Double? = nil,
        recordingID: UUID? = nil,
        createdAt: Date? = nil,
        sourceAudioDurationSeconds: Double? = nil
    ) {
        self.text = text
        self.transcriptionDurationSeconds = Self.validDuration(transcriptionDurationSeconds)
        self.recordingID = recordingID
        self.createdAt = createdAt
        self.sourceAudioDurationSeconds = Self.validDuration(sourceAudioDurationSeconds)
    }

    private static func validDuration(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 0 else { return nil }
        return value
    }
}

/// One-way projection from runtime transcript history into durable product rows.
///
/// Legacy rows without an explicit recording identity retain the historical
/// deterministic text+occurrence UUID. Rows with a real runtime UUID preserve it.
/// Explicit-ID rows do not advance the legacy duplicate occurrence counter, so
/// adding newer metadata-rich rows cannot silently renumber old legacy IDs.
public enum SuperDictateLegacyHistoryMigrator {
    public static func recordings(
        from entries: [SuperDictateLegacyHistoryEntry]
    ) -> [SuperDictateRecording] {
        var legacyOccurrences: [String: Int] = [:]
        var result: [SuperDictateRecording] = []
        result.reserveCapacity(entries.count)

        for entry in entries {
            let text = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            let occurrence = legacyOccurrences[text, default: 0]
            let id: UUID
            if let recordingID = entry.recordingID {
                id = recordingID
            } else {
                id = stableRecordingID(text: text, occurrence: occurrence)
                legacyOccurrences[text] = occurrence + 1
            }

            result.append(
                SuperDictateRecording(
                    id: id,
                    title: suggestedTitle(from: text),
                    transcript: text,
                    summary: nil,
                    createdAt: entry.createdAt,
                    durationSeconds: entry.sourceAudioDurationSeconds,
                    people: [],
                    requiresAttention: false
                )
            )
        }
        return result
    }

    public static func archive(
        from entries: [SuperDictateLegacyHistoryEntry]
    ) -> SuperDictateLibraryArchive {
        let recordings = recordings(from: entries)
        return SuperDictateLibraryArchive(
            recordings: recordings,
            memoryDocuments: recordings.map {
                SuperDictateMemoryDocument(recording: $0)
            }
        )
    }

    /// Stable fallback identity for pre-metadata history rows only.
    public static func stableRecordingID(
        text: String,
        occurrence: Int
    ) -> UUID {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var hasher = SHA256()
        hasher.update(
            data: Data(
                "superdictate-history-v1\u{0}\(max(0, occurrence))\u{0}\(normalizedText)".utf8
            )
        )
        let bytes = Array(hasher.finalize().prefix(16))
        guard bytes.count == 16 else { return UUID() }
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func suggestedTitle(from text: String) -> String {
        let flat = text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard flat.count > 68 else { return flat }
        return String(flat.prefix(67)) + "…"
    }
}
