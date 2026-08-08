import Foundation
import SuperDictateCore

struct ProductLegacyHistoryValue: Sendable {
    let text: String
    let transcriptionDurationSeconds: Double?
}

/// The background agent is the only durable Library writer.
///
/// Calls are fire-and-forget from the runtime main actor. All file I/O is
/// serialized by one actor so dictation completion never waits on Library work.
enum ProductLibraryPersistence {
    @MainActor
    static func scheduleLegacyHistoryMerge(_ values: [ProductLegacyHistoryValue]) {
        guard !values.isEmpty else { return }
        guard let rootDirectory = resolvedRootDirectory() else { return }

        let entries = values.map {
            SuperDictateLegacyHistoryEntry(
                text: $0.text,
                transcriptionDurationSeconds: $0.transcriptionDurationSeconds
            )
        }

        Task.detached(priority: .utility) {
            await ProductLibraryPersistenceWorker.shared.merge(
                entries,
                rootDirectory: rootDirectory
            )
        }
    }

    @MainActor
    static func scheduleClear() {
        guard let rootDirectory = resolvedRootDirectory() else { return }
        Task.detached(priority: .utility) {
            await ProductLibraryPersistenceWorker.shared.clear(
                rootDirectory: rootDirectory
            )
        }
    }

    @MainActor
    private static func resolvedRootDirectory() -> URL? {
        do {
            return try superDictateApplicationSupportDirectory()
        } catch {
            log("product Library root unavailable: \(error.localizedDescription)")
            return nil
        }
    }
}

private actor ProductLibraryPersistenceWorker {
    static let shared = ProductLibraryPersistenceWorker()

    private var store: JSONSuperDictateLibraryStore?
    private var storeRootDirectory: URL?

    func merge(
        _ entries: [SuperDictateLegacyHistoryEntry],
        rootDirectory: URL
    ) async {
        guard !entries.isEmpty else { return }

        do {
            let store = try libraryStore(rootDirectory: rootDirectory)
            let archive = try await store.load()
            let result = SuperDictateLegacyLibraryMerger.merge(entries, into: archive)
            guard result.changed else { return }
            try await store.save(result.archive)
            log(
                "product Library merged legacy history "
                + "(recordings=\(result.addedRecordingCount), documents=\(result.addedDocumentCount))"
            )
        } catch {
            // Library indexing is secondary to successful dictation. Failure here
            // must never turn an inserted transcript into a failed dictation.
            log("product Library merge failed: \(error.localizedDescription)")
        }
    }

    func clear(rootDirectory: URL) async {
        do {
            let store = try libraryStore(rootDirectory: rootDirectory)
            try await store.save(SuperDictateLibraryArchive())
            log("product Library cleared because transcript history is disabled")
        } catch {
            log("product Library clear failed: \(error.localizedDescription)")
        }
    }

    private func libraryStore(
        rootDirectory: URL
    ) throws -> JSONSuperDictateLibraryStore {
        if let store,
           storeRootDirectory == rootDirectory {
            return store
        }

        let created = try JSONSuperDictateLibraryStore(rootDirectory: rootDirectory)
        store = created
        storeRootDirectory = rootDirectory
        return created
    }
}
