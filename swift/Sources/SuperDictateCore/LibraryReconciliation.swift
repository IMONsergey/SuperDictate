import Foundation

public struct SuperDictateLibraryReconciliationResult: Equatable, Sendable {
    public var archive: SuperDictateLibraryArchive
    public var snapshot: SuperDictateProductSnapshot

    public init(
        archive: SuperDictateLibraryArchive,
        snapshot: SuperDictateProductSnapshot
    ) {
        self.archive = archive
        self.snapshot = snapshot
    }
}

/// Pure merge policy between the ephemeral runtime projection and durable
/// product memory.
///
/// The live bridge is intentionally lossy and bounded. It may know current
/// status and recent transcript rows, but it is not allowed to infer deletion
/// from absence. Durable Library metadata and rich evidence therefore survive
/// recent-history eviction or clearing.
public enum SuperDictateLibraryReconciler {
    public static func reconcile(
        liveSnapshot: SuperDictateProductSnapshot,
        durableArchive: SuperDictateLibraryArchive
    ) -> SuperDictateLibraryReconciliationResult {
        let recordings = mergeRecordings(
            live: liveSnapshot.recordings,
            durable: durableArchive.recordings
        )
        let tasks = mergeTasks(
            live: liveSnapshot.tasks,
            durable: durableArchive.tasks
        )
        let documents = mergeMemoryDocuments(
            recordings: recordings,
            durable: durableArchive.memoryDocuments
        )
        let archive = SuperDictateLibraryArchive(
            recordings: recordings,
            tasks: tasks,
            memoryDocuments: documents
        )
        let snapshot = SuperDictateProductSnapshot(
            status: liveSnapshot.status,
            recordings: recordings,
            tasks: tasks,
            activeRecordingStartedAt: liveSnapshot.activeRecordingStartedAt,
            issueMessage: liveSnapshot.issueMessage
        )
        return SuperDictateLibraryReconciliationResult(
            archive: archive,
            snapshot: snapshot
        )
    }

    private static func mergeRecordings(
        live: [SuperDictateRecording],
        durable: [SuperDictateRecording]
    ) -> [SuperDictateRecording] {
        var durableByID: [UUID: SuperDictateRecording] = [:]
        for recording in durable {
            durableByID[recording.id] = recording
        }

        var result: [SuperDictateRecording] = []
        var seen: Set<UUID> = []
        for liveRecording in live {
            guard seen.insert(liveRecording.id).inserted else { continue }
            guard let durableRecording = durableByID[liveRecording.id] else {
                result.append(liveRecording)
                continue
            }

            // Durable product metadata wins over the lossy legacy bridge.
            // Runtime attention is the exception because it is live state.
            result.append(
                SuperDictateRecording(
                    id: durableRecording.id,
                    title: durableRecording.title,
                    transcript: durableRecording.transcript.isEmpty
                        ? liveRecording.transcript
                        : durableRecording.transcript,
                    summary: durableRecording.summary,
                    createdAt: durableRecording.createdAt,
                    durationSeconds: durableRecording.durationSeconds
                        ?? liveRecording.durationSeconds,
                    people: durableRecording.people,
                    requiresAttention: durableRecording.requiresAttention
                        || liveRecording.requiresAttention
                )
            )
        }

        // Absence from bounded recent history is never a delete signal.
        for recording in durable where seen.insert(recording.id).inserted {
            result.append(recording)
        }
        return result
    }

    private static func mergeTasks(
        live: [SuperDictateTask],
        durable: [SuperDictateTask]
    ) -> [SuperDictateTask] {
        var liveByID: [UUID: SuperDictateTask] = [:]
        for task in live {
            liveByID[task.id] = task
        }

        var result: [SuperDictateTask] = []
        var seen: Set<UUID> = []
        for durableTask in durable {
            guard seen.insert(durableTask.id).inserted else { continue }
            result.append(liveByID[durableTask.id] ?? durableTask)
        }
        for liveTask in live where seen.insert(liveTask.id).inserted {
            result.append(liveTask)
        }
        return result
    }

    private static func mergeMemoryDocuments(
        recordings: [SuperDictateRecording],
        durable: [SuperDictateMemoryDocument]
    ) -> [SuperDictateMemoryDocument] {
        var durableByID: [UUID: SuperDictateMemoryDocument] = [:]
        for document in durable {
            durableByID[document.recordingID] = document
        }

        return recordings.map { recording in
            // Never downgrade timed/speaker-rich evidence to the bridge's
            // one-segment untimed projection.
            durableByID[recording.id]
                ?? SuperDictateMemoryDocument(recording: recording)
        }
    }
}
