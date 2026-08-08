import Foundation
import SuperDictateCore

/// Reconciles the fast live runtime projection with the durable local Library.
///
/// The live bridge is intentionally ephemeral: it reflects the current agent
/// and the bounded recent-history cache. The Library is append-preserving: once
/// a recording has been imported, shrinking or clearing recent history does not
/// silently delete it from durable product memory.
actor NativeProductLibraryCoordinator {
    private let store: JSONSuperDictateLibraryStore

    init(rootDirectory: URL) throws {
        store = try JSONSuperDictateLibraryStore(rootDirectory: rootDirectory)
    }

    func synchronize(
        liveSnapshot: SuperDictateProductSnapshot
    ) async throws -> SuperDictateProductSnapshot {
        let archive = try await store.load()
        let mergedRecordings = mergeRecordings(
            live: liveSnapshot.recordings,
            durable: archive.recordings
        )
        let mergedTasks = mergeTasks(
            live: liveSnapshot.tasks,
            durable: archive.tasks
        )
        let mergedDocuments = mergeMemoryDocuments(
            recordings: mergedRecordings,
            durable: archive.memoryDocuments
        )

        let nextArchive = SuperDictateLibraryArchive(
            recordings: mergedRecordings,
            tasks: mergedTasks,
            memoryDocuments: mergedDocuments
        )
        if nextArchive != archive {
            try await store.save(nextArchive)
        }

        return SuperDictateProductSnapshot(
            status: liveSnapshot.status,
            recordings: mergedRecordings,
            tasks: mergedTasks,
            activeRecordingStartedAt: liveSnapshot.activeRecordingStartedAt,
            issueMessage: liveSnapshot.issueMessage
        )
    }

    private func mergeRecordings(
        live: [SuperDictateRecording],
        durable: [SuperDictateRecording]
    ) -> [SuperDictateRecording] {
        let durableByID = Dictionary(
            uniqueKeysWithValues: durable.map { ($0.id, $0) }
        )
        var result: [SuperDictateRecording] = []
        var seen: Set<UUID> = []

        for liveRecording in live {
            let recording: SuperDictateRecording
            if let durableRecording = durableByID[liveRecording.id] {
                // Durable product metadata wins over the lossy legacy bridge.
                // Runtime attention remains live because it can change without
                // rewriting the persisted Library.
                recording = SuperDictateRecording(
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
                    requiresAttention: liveRecording.requiresAttention
                        || durableRecording.requiresAttention
                )
            } else {
                recording = liveRecording
            }
            guard seen.insert(recording.id).inserted else { continue }
            result.append(recording)
        }

        // Preserve durable recordings that have fallen out of the bounded
        // recent-history cache. Their source audio is managed separately.
        for recording in durable where seen.insert(recording.id).inserted {
            result.append(recording)
        }
        return result
    }

    private func mergeTasks(
        live: [SuperDictateTask],
        durable: [SuperDictateTask]
    ) -> [SuperDictateTask] {
        let liveByID = Dictionary(uniqueKeysWithValues: live.map { ($0.id, $0) })
        var result = durable.map { liveByID[$0.id] ?? $0 }
        var seen = Set(result.map(\.id))
        for task in live where seen.insert(task.id).inserted {
            result.append(task)
        }
        return result
    }

    private func mergeMemoryDocuments(
        recordings: [SuperDictateRecording],
        durable: [SuperDictateMemoryDocument]
    ) -> [SuperDictateMemoryDocument] {
        let durableByID = Dictionary(
            uniqueKeysWithValues: durable.map { ($0.recordingID, $0) }
        )
        return recordings.map { recording in
            // Never downgrade rich timed evidence to the bridge's legacy
            // untimed transcript projection.
            durableByID[recording.id]
                ?? SuperDictateMemoryDocument(recording: recording)
        }
    }
}
