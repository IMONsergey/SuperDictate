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
/// Legacy history contains text and optional transcription timing but no UUID or
/// capture timestamp. The migrator therefore:
/// - derives a deterministic UUID from immutable legacy content;
/// - uses an occurrence ordinal only to distinguish identical duplicate rows;
/// - preserves the transcript verbatim apart from outer whitespace trimming;
/// - keeps `createdAt == nil` instead of inventing chronology;
/// - maps the known transcription duration into the product duration field.
///
/// Re-running the migration with the same ordered legacy archive is idempotent.
public enum SuperDictateLegacyHistoryMigrator {
    private static let namespace = "com.superdictate.legacy-history.v1"

    public static func recordings(
        from entries: [SuperDictateLegacyHistoryEntry]
    ) -> [SuperDictateRecording] {
        var occurrenceByFingerprint: [String: Int] = [:]
        var result: [SuperDictateRecording] = []
        result.reserveCapacity(entries.count)

        for entry in entries {
            let text = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            let fingerprint = contentFingerprint(
                text: text,
                durationSeconds: entry.transcriptionDurationSeconds
            )
            let ordinal = occurrenceByFingerprint[fingerprint, default: 0]
            occurrenceByFingerprint[fingerprint] = ordinal + 1

            result.append(
                SuperDictateRecording(
                    id: deterministicUUID(
                        fingerprint: fingerprint,
                        occurrenceOrdinal: ordinal
                    ),
                    title: suggestedTitle(from: text),
                    transcript: text,
                    createdAt: nil,
                    durationSeconds: entry.transcriptionDurationSeconds
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
            memoryDocuments: recordings.map(SuperDictateMemoryDocument.init(recording:))
        )
    }

    private static func contentFingerprint(
        text: String,
        durationSeconds: Double?
    ) -> String {
        let duration = durationSeconds.map { String(format: "%.9f", $0) } ?? "unknown"
        let payload = "\(namespace)\n\(duration)\n\(text)"
        return SHA256.hash(data: Data(payload.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func deterministicUUID(
        fingerprint: String,
        occurrenceOrdinal: Int
    ) -> UUID {
        let payload = "\(namespace)\n\(fingerprint)\n\(occurrenceOrdinal)"
        var bytes = Array(SHA256.hash(data: Data(payload.utf8)).prefix(16))

        // RFC 4122 variant + version-5-style marker. The digest is SHA-256, but
        // the UUID bit layout remains standards-friendly and visibly stable.
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80

        let uuidString = String(
            format: "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5],
            bytes[6], bytes[7],
            bytes[8], bytes[9],
            bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuidString: uuidString)!
    }

    private static func suggestedTitle(from text: String) -> String {
        let flat = text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard flat.count > 64 else { return flat }
        return String(flat.prefix(63)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
