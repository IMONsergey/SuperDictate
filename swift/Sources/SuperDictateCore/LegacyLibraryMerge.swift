import Foundation

public struct SuperDictateLegacyLibraryMergeResult: Equatable, Sendable {
    public var archive: SuperDictateLibraryArchive
    public var addedRecordingCount: Int
    public var addedDocumentCount: Int
    public var repairedRecordingMetadataCount: Int

    public init(
        archive: SuperDictateLibraryArchive,
        addedRecordingCount: Int,
        addedDocumentCount: Int,
        repairedRecordingMetadataCount: Int = 0
    ) {
        self.archive = archive
        self.addedRecordingCount = addedRecordingCount
        self.addedDocumentCount = addedDocumentCount
        self.repairedRecordingMetadataCount = repairedRecordingMetadataCount
    }

    public var changed: Bool {
        addedRecordingCount > 0
            || addedDocumentCount > 0
            || repairedRecordingMetadataCount > 0
    }
}

/// Migration-only merge from runtime transcript history into the durable
/// Library. Existing durable objects always win, except for one narrowly
/// defined repair of metadata written by the pre-v2 legacy migrator.
public enum SuperDictateLegacyLibraryMerger {
    public static func merge(
        _ entries: [SuperDictateLegacyHistoryEntry],
        into archive: SuperDictateLibraryArchive
    ) -> SuperDictateLegacyLibraryMergeResult {
        let repair = repairLegacyDurationPollution(in: archive)
        let migrated = SuperDictateLegacyHistoryMigrator.archive(from: entries)
        var next = repair.archive
        var recordingIDs = Set(next.recordings.map(\.id))
        var documentIDs = Set(next.memoryDocuments.map(\.recordingID))
        var addedRecordings = 0
        var addedDocuments = 0

        for recording in migrated.recordings {
            guard recordingIDs.insert(recording.id).inserted else { continue }
            next.recordings.append(recording)
            addedRecordings += 1
        }

        for document in migrated.memoryDocuments {
            guard documentIDs.insert(document.recordingID).inserted else { continue }
            next.memoryDocuments.append(document)
            addedDocuments += 1
        }

        return SuperDictateLegacyLibraryMergeResult(
            archive: next,
            addedRecordingCount: addedRecordings,
            addedDocumentCount: addedDocuments,
            repairedRecordingMetadataCount: repair.repairedCount
        )
    }

    /// Releases written before truthful metadata v2 could store ASR processing
    /// time in `SuperDictateRecording.durationSeconds`. We can identify those
    /// rows without guessing because they use the deterministic legacy
    /// text+occurrence UUID and have no source capture timestamp.
    ///
    /// Explicit runtime UUID rows never advance the fallback occurrence counter,
    /// matching `SuperDictateLegacyHistoryMigrator` semantics.
    public static func repairLegacyDurationPollution(
        in archive: SuperDictateLibraryArchive
    ) -> (archive: SuperDictateLibraryArchive, repairedCount: Int) {
        var next = archive
        var legacyOccurrences: [String: Int] = [:]
        var repairedCount = 0

        for index in next.recordings.indices {
            let recording = next.recordings[index]
            let text = recording.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            let occurrence = legacyOccurrences[text, default: 0]
            let expectedLegacyID = SuperDictateLegacyHistoryMigrator.stableRecordingID(
                text: text,
                occurrence: occurrence
            )
            guard recording.id == expectedLegacyID else {
                // Real runtime UUID rows do not consume a legacy occurrence.
                continue
            }

            legacyOccurrences[text] = occurrence + 1
            guard recording.createdAt == nil,
                  recording.durationSeconds != nil else {
                continue
            }

            next.recordings[index].durationSeconds = nil
            repairedCount += 1
        }

        return (next, repairedCount)
    }
}
