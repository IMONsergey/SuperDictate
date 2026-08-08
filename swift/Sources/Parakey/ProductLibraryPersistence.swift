import Foundation
import SuperDictateCore

struct ProductLegacyHistoryValue: Sendable {
    let text: String
    let transcriptionDurationSeconds: Double?
}

/// Fire-and-forget adapter from the existing successful-history path into the
/// durable private Library. Dictation completion never waits on Library I/O.
enum ProductLibraryPersistence {
    static func scheduleLegacyHistoryMerge(_ values: [ProductLegacyHistoryValue]) {
        let entries = values.map {
            SuperDictateLegacyHistoryEntry(
                text: $0.text,
                transcriptionDurationSeconds: $0.transcriptionDurationSeconds
            )
        }

        Task.detached(priority: .utility) {
            await ProductLibraryPersistenceWorker.shared.merge(entries)
        }
    }
}

private actor ProductLibraryPersistenceWorker {
    static let shared = ProductLibraryPersistenceWorker()

    private var store: JSONSuperDictateLibraryStore?

    func merge(_ entries: [SuperDictateLegacyHistoryEntry]) async {
        guard !entries.isEmpty else { return }

        do {
            let store = try libraryStore()
            let archive = try await store.load()
            let result = SuperDictateLegacyLibraryMerger.merge(entries, into: archive)
            guard result.changed else { return }
            try await store.save(result.archive)
            log(
                "product Library merged legacy history "
                + "(recordings=\(result.addedRecordingCount), documents=\(result.addedDocumentCount))"
            )
        } catch {
            // The Library is a rebuildable product index. Failure here must not
            // change transcript insertion/history success semantics.
            log("product Library merge failed: \(error.localizedDescription)")
        }
    }

    private func libraryStore() throws -> JSONSuperDictateLibraryStore {
        if let store { return store }
        let root = try superDictateApplicationSupportDirectory()
        let created = try JSONSuperDictateLibraryStore(rootDirectory: root)
        store = created
        return created
    }
}
