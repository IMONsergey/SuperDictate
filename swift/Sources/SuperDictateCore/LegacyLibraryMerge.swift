import Foundation

public struct SuperDictateLegacyLibraryMergeResult: Equatable, Sendable {
    public var archive: SuperDictateLibraryArchive
    public var addedRecordingCount: Int
    public var addedDocumentCount: Int

    public init(
        archive: SuperDictateLibraryArchive,
        addedRecordingCount: Int,
        addedDocumentCount: Int
    ) {
        self.archive = archive
        self.addedRecordingCount = addedRecordingCount
        self.addedDocumentCount = addedDocumentCount
    }

    public var changed: Bool {
        addedRecordingCount > 0 || addedDocumentCount > 0
    }
}

/// Adds legacy rolling-history entries to a durable Library archive without
/// replacing richer durable state.
///
/// The old history format does not know stable source chronology, people,
/// summaries, tasks or rich evidence spans. Once a durable object exists, that
/// object wins. Legacy history is migration input only.
public enum SuperDictateLegacyLibraryMerger {
    public static func merge(
        _ entries: [SuperDictateLegacyHistoryEntry],
        into archive: SuperDictateLibraryArchive
    ) -> SuperDictateLegacyLibraryMergeResult {
        let migrated = SuperDictateLegacyHistoryMigrator.archive(from: entries)
        var next = archive

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
            addedDocumentCount: addedDocuments
        )
    }
}
