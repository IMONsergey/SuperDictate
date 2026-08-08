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
/// Durable content and presentation state are deliberately separated:
/// - absence from the bounded live cache is never a delete signal;
/// - genuinely new live recordings may be appended to the durable archive;
/// - existing durable metadata is never downgraded by a lossy live projection;
/// - live operational state (status, issue text, `requiresAttention`) is applied
///   only to the returned presentation snapshot and is never persisted here;
/// - missing evidence documents are created from durable recording content.
public enum SuperDictateLibraryReconciler {
    public static func reconcile(
        archive: SuperDictateLibraryArchive,
        liveSnapshot: SuperDictateProductSnapshot
    ) -> SuperDictateLibraryReconciliationResult {
        var next = archive
        var durableIDs = Set(next.recordings.map(\.id))
        var documentIDs = Set(next.memoryDocuments.map(\.recordingID))
        var addedRecordings = 0
        var addedDocuments = 0

        for live in liveSnapshot.recordings where durableIDs.insert(live.id).inserted {
            next.recordings.append(durableProjection(from: live))
            addedRecordings += 1
        }

        for recording in next.recordings {
            guard documentIDs.insert(recording.id).inserted else { continue }
            next.memoryDocuments.append(SuperDictateMemoryDocument(recording: recording))
            addedDocuments += 1
        }

        let durableByID = Dictionary(
            uniqueKeysWithValues: next.recordings.map { ($0.id, $0) }
        )
        var visibleRecordings: [SuperDictateRecording] = []
        var visibleIDs: Set<UUID> = []

        // Keep the bounded live order at the front (important for legacy rows
        // without source dates), but source durable metadata for matching IDs.
        for live in liveSnapshot.recordings {
            guard visibleIDs.insert(live.id).inserted else { continue }
            if let durable = durableByID[live.id] {
                visibleRecordings.append(
                    presentationRecording(durable: durable, live: live)
                )
            } else {
                visibleRecordings.append(live)
            }
        }

        // Durable rows that aged out of recent history remain visible after the
        // current live slice. Their source audio lifecycle is managed elsewhere.
        for durable in next.recordings where visibleIDs.insert(durable.id).inserted {
            visibleRecordings.append(durable)
        }

        let snapshot = SuperDictateProductSnapshot(
            status: liveSnapshot.status,
            recordings: visibleRecordings,
            tasks: presentationTasks(
                durable: next.tasks,
                live: liveSnapshot.tasks
            ),
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

    private static func durableProjection(
        from live: SuperDictateRecording
    ) -> SuperDictateRecording {
        SuperDictateRecording(
            id: live.id,
            title: live.title,
            transcript: live.transcript,
            summary: live.summary,
            createdAt: live.createdAt,
            durationSeconds: live.durationSeconds,
            people: live.people,
            requiresAttention: false
        )
    }

    private static func presentationRecording(
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
            requiresAttention: durable.requiresAttention || live.requiresAttention
        )
    }

    private static func presentationTasks(
        durable: [SuperDictateTask],
        live: [SuperDictateTask]
    ) -> [SuperDictateTask] {
        var liveByID = Dictionary(uniqueKeysWithValues: live.map { ($0.id, $0) })
        var result = durable.map { durableTask in
            liveByID.removeValue(forKey: durableTask.id) ?? durableTask
        }
        var seen = Set(result.map(\.id))
        for task in live where seen.insert(task.id).inserted {
            result.append(task)
        }
        return result
    }

    private static func preferredText(_ durable: String, fallback live: String) -> String {
        durable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? live : durable
    }

    private static func preferredOptionalText(_ durable: String?, fallback live: String?) -> String? {
        guard let durable else { return live }
        return durable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? live : durable
    }
}
