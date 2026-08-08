import Foundation

public struct SuperDictateLibraryReconciliationResult: Equatable, Sendable {
    public var archive: SuperDictateLibraryArchive
    public var snapshot: SuperDictateProductSnapshot
    public var addedRecordingCount: Int
    public var addedDocumentCount: Int

    public init(
        archive: SuperDictateLibraryArchive,
        snapshot: SuperDictateProductSnapshot,
        addedRecordingCount: Int,
        addedDocumentCount: Int
    ) {
        self.archive = archive
        self.snapshot = snapshot
        self.addedRecordingCount = addedRecordingCount
        self.addedDocumentCount = addedDocumentCount
    }

    public var archiveChanged: Bool {
        addedRecordingCount > 0 || addedDocumentCount > 0
    }
}

/// Combines volatile runtime state with the durable Library without treating the
/// bounded recent-history cache as authoritative storage.
///
/// Rules:
/// - durable recordings/tasks/documents are never removed because they are absent
///   from the live runtime snapshot;
/// - a live recording that does not exist durably is appended;
/// - richer durable metadata wins over poorer live/legacy metadata;
/// - live `requiresAttention` is overlaid for matching records because it is
///   operational state, not durable content;
/// - missing evidence documents are created from the reconciled recording;
/// - runtime status/issue state remains live while recordings/tasks come from the
///   reconciled durable archive.
public enum SuperDictateLibraryReconciler {
    public static func reconcile(
        archive: SuperDictateLibraryArchive,
        liveSnapshot: SuperDictateProductSnapshot
    ) -> SuperDictateLibraryReconciliationResult {
        var next = archive
        var indexByID: [UUID: Int] = Dictionary(
            uniqueKeysWithValues: next.recordings.enumerated().map { ($0.element.id, $0.offset) }
        )
        var documentIDs = Set(next.memoryDocuments.map(\.recordingID))
        var addedRecordings = 0
        var addedDocuments = 0

        for live in liveSnapshot.recordings {
            if let index = indexByID[live.id] {
                next.recordings[index] = mergedDurableRecording(
                    durable: next.recordings[index],
                    live: live
                )
            } else {
                indexByID[live.id] = next.recordings.count
                next.recordings.append(live)
                addedRecordings += 1
            }
        }

        for recording in next.recordings {
            guard documentIDs.insert(recording.id).inserted else { continue }
            next.memoryDocuments.append(SuperDictateMemoryDocument(recording: recording))
            addedDocuments += 1
        }

        let snapshot = SuperDictateProductSnapshot(
            status: liveSnapshot.status,
            recordings: next.recordings,
            tasks: next.tasks,
            activeRecordingStartedAt: liveSnapshot.activeRecordingStartedAt,
            issueMessage: liveSnapshot.issueMessage
        )

        return SuperDictateLibraryReconciliationResult(
            archive: next,
            snapshot: snapshot,
            addedRecordingCount: addedRecordings,
            addedDocumentCount: addedDocuments
        )
    }

    private static func mergedDurableRecording(
        durable: SuperDictateRecording,
        live: SuperDictateRecording
    ) -> SuperDictateRecording {
        SuperDictateRecording(
            id: durable.id,
            title: preferredText(durable.title, fallback: live.title),
            transcript: preferredText(durable.transcript, fallback: live.transcript),
            summary: preferredOptionalText(durable.summary, fallback: live.summary),
            createdAt: durable.createdAt ?? live.createdAt,
            durationSeconds: durable.durationSeconds ?? live.durationSeconds,
            people: durable.people.isEmpty ? live.people : durable.people,
            requiresAttention: live.requiresAttention
        )
    }

    private static func preferredText(_ durable: String, fallback live: String) -> String {
        durable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? live : durable
    }

    private static func preferredOptionalText(_ durable: String?, fallback live: String?) -> String? {
        guard let durable else { return live }
        return durable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? live : durable
    }
}
