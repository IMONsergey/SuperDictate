import CryptoKit
import Foundation

public struct SuperDictateLegacyHistoryEntry: Equatable, Sendable {
    public var text: String
    public var transcriptionDurationSeconds: Double?

    public init(
        text: String,
        transcriptionDurationSeconds: Double? = nil
    ) {
        self.text = text
        if let duration = transcriptionDurationSeconds,
           duration.isFinite,
           duration >= 0 {
            self.transcriptionDurationSeconds = duration
        } else {
            self.transcriptionDurationSeconds = nil
        }
    }
}

/// One-way projection from the pre-Library transcript archive into stable
/// product identities.
///
/// The UUID algorithm intentionally matches the already-shipped temporary
/// identity in `ProductRuntimeBridge.swift`: normalized transcript text plus
/// duplicate occurrence ordinal. This prevents a legacy row from changing ID
/// when it moves from the live bridge snapshot into the persisted Library.
///
/// Legacy capture chronology does not exist. `createdAt` therefore stays nil.
public enum SuperDictateLegacyHistoryMigrator {
    public static func recordings(
        from entries: [SuperDictateLegacyHistoryEntry]
    ) -> [SuperDictateRecording] {
        var occurrences: [String: Int] = [:]
        var result: [SuperDictateRecording] = []
        result.reserveCapacity(entries.count)

        for entry in entries {
            let text = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            let occurrence = occurrences[text, default: 0]
            occurrences[text] = occurrence + 1

            result.append(
                SuperDictateRecording(
                    id: stableRecordingID(text: text, occurrence: occurrence),
                    title: suggestedTitle(from: text),
                    transcript: text,
                    summary: nil,
                    createdAt: nil,
                    durationSeconds: entry.transcriptionDurationSeconds,
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

    /// Public so the runtime bridge can eventually delegate to the same source
    /// of truth and delete its temporary duplicate implementation.
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
